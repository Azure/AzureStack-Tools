#!/usr/bin/env bash
#
# Copyright (c) Microsoft Corporation. All rights reserved.
#
# Description:
# A script to build immutable, integrity-protected images that are suitable for
# deploying into Azure Local CVMs. These images feature a read-only rootfs with
# dm-verity verification, TPM measurements, and cloud-init support.
#
set -euo pipefail

# ============================================================================
# Function Definitions
# ============================================================================

# Function to log to both console and file
log_progress() {
  echo "$@" | tee -a "$LOGFILE"
}

# Usage function
usage() {
  echo "Usage: $0 --username <username> --image <vhdx_filename> [OPTIONS]"
  echo ""
  echo "Required arguments:"
  echo "  --username <username>     Username for the created user account"
  echo "  --image <vhdx_filename>   Output VHDX filename"
  echo ""
  echo "Optional arguments:"
  echo "  --password                Prompt for a password during the build"
  echo "  --passwordless-sudo       Allow sudo without password prompt (less secure)"
  echo "  --password-hash <hash>    Use a pre-generated password hash instead of prompting for a password"
  echo "  --packages <pkg1,pkg2>    Comma-separated list of additional packages to install"
  echo "  --ssh-key <pubkey_file>   Path to SSH public key file for passwordless login"
  echo "  --rootfs-overlay <dir>    Directory containing files to overlay onto the rootfs"
  echo "                            Files are copied preserving directory structure"
  echo "  --allow-ssh-password      Allow password authentication over SSH (disabled by default)"
  echo "  --allow-serial-console    Enable serial console login (disabled by default)"
  echo "  --package-dir <dir>       Directory containing .deb packages to install via dpkg"
  echo "                            All .deb files in the directory will be installed"
  echo "  --insiders-fast           Enable packages.microsoft.com insiders-fast apt repo"
  echo "  --verbose-output          Print the full build log to the console instead of just the summary"
  echo ""
  echo "Examples:"
  echo "  $0 --username user --image vm.vhdx"
  echo "  $0 --username user --image vm.vhdx --packages 'curl,wget,htop'"
  echo "  $0 --username user --image vm.vhdx --ssh-key ~/.ssh/id_rsa.pub"
  echo "  $0 --username user --image vm.vhdx --rootfs-overlay ./custom_files"
  echo "  $0 --username user --image vm.vhdx --password-hash '\$6\$rounds=5000\$saltsalt\$hashedpassword'"
  exit 1
}

# Make sure the script host has all the packages required to build the image
install_dependencies() {
  for pkg in qemu-utils dracut systemd-boot-efi libsquashfs-dev cryptsetup-bin squashfs-tools debootstrap openssh-server rsync bc; do
      if ! dpkg -s "$pkg" >/dev/null 2>&1; then
          log_progress "  Installing $pkg"
          sudo apt install -y "$pkg" >> "$LOGFILE" 2>&1
      fi
  done
}

# Prepare the build directory and rootfs
prepare_build_environment() {
  # Remove existing rootfs if present
  if [[ -d "$ROOTFS_DIR" ]]; then
    # Delete the contents rather than removing the entire directory because the docker
    # build mounts it as a volume which cannot be removed by the script.
    sudo find "$ROOTFS_DIR" -mindepth 1 -delete 2>/dev/null || {
      log_progress "  WARNING: Could not delete some rootfs contents"
    }
  else
    mkdir -p "$ROOTFS_DIR"
  fi
}

# Prepare and populate the rootfs using debootstrap and any overlays
# and custom packages.
create_ubuntu_rootfs() {
  log_progress "  Running debootstrap for Ubuntu Noble (24.04)..."
  APT_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/cvmos/apt"
  mkdir -p "$APT_CACHE_DIR"
  sudo debootstrap --verbose --arch=amd64 --cache-dir="$APT_CACHE_DIR" noble "$ROOTFS_DIR" http://security.ubuntu.com/ubuntu/ >> "$LOGFILE" 2>&1

  configure_tmpfs
  install_packages
  configure_services
  configure_cloud_init
  create_user_account
  apply_rootfs_overlay
  cleanup_chroot_mounts
}

configure_tmpfs() {
  log_progress "  Configuring tmpfs mounts for runtime..."
  echo "tmpfs /home tmpfs defaults,size=512M 0 0" | sudo tee -a "$ROOTFS_DIR/etc/fstab" >> "$LOGFILE"
  echo "tmpfs /var tmpfs defaults,size=512M 0 0" | sudo tee -a "$ROOTFS_DIR/etc/fstab" >> "$LOGFILE"
  echo "tmpfs /tmp tmpfs defaults,size=256M 0 0" | sudo tee -a "$ROOTFS_DIR/etc/fstab" >> "$LOGFILE"
  echo "tmpfs /root tmpfs defaults,size=128M,uid=0,gid=0,mode=0700 0 0" | sudo tee -a "$ROOTFS_DIR/etc/fstab" >> "$LOGFILE"
  echo "tmpfs /run tmpfs defaults,size=128M 0 0" | sudo tee -a "$ROOTFS_DIR/etc/fstab" >> "$LOGFILE"
}

install_packages() {
  log_progress "  Installing required packages..."

  cp rootfs-files/sources.list "$ROOTFS_DIR/etc/apt/sources.list"

  sudo mount -t proc proc "$ROOTFS_DIR/proc"
  sudo mount -t sysfs sysfs "$ROOTFS_DIR/sys"
  sudo mount --bind /dev "$ROOTFS_DIR/dev"

  log_progress "  Installing Microsoft GPG keys..."
  sudo chroot "$ROOTFS_DIR" /bin/bash <<'KEY_EOF' >> "$LOGFILE" 2>&1
set -euo pipefail
apt update
apt install -y ca-certificates wget apt-transport-https lsb-release gnupg

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT
mkdir -p /usr/share/keyrings

# Legacy key (pre-Spring 2025 repos)
wget -q https://packages.microsoft.com/keys/microsoft.asc -O "$TMPDIR/microsoft.asc"
ACTUAL=$(sha256sum "$TMPDIR/microsoft.asc" | awk '{print $1}')
if [ "$ACTUAL" != "2fa9c05d591a1582a9aba276272478c262e95ad00acf60eaee1644d93941e3c6" ]; then
  echo "SHA256 mismatch for microsoft.asc!" >&2; exit 1
fi
gpg --dearmor "$TMPDIR/microsoft.asc"
cp "$TMPDIR/microsoft.asc.gpg" /etc/apt/trusted.gpg.d/
mv "$TMPDIR/microsoft.asc.gpg" /usr/share/keyrings/microsoft-prod.gpg

# Current key (Spring 2025+ repos)
wget -q https://packages.microsoft.com/keys/microsoft-2025.asc -O "$TMPDIR/microsoft-2025.asc"
ACTUAL=$(sha256sum "$TMPDIR/microsoft-2025.asc" | awk '{print $1}')
if [ "$ACTUAL" != "d45224d594d969f084232deaaf97c58ca502a9d964c362d7aaef5a76e16b3dd1" ]; then
  echo "SHA256 mismatch for microsoft-2025.asc!" >&2; exit 1
fi
gpg --dearmor "$TMPDIR/microsoft-2025.asc"
cp "$TMPDIR/microsoft-2025.asc.gpg" /etc/apt/trusted.gpg.d/
mv "$TMPDIR/microsoft-2025.asc.gpg" /usr/share/keyrings/microsoft-prod-2025.gpg
KEY_EOF

  log_progress "  Adding packages.microsoft.com production repository..."
  sudo chroot "$ROOTFS_DIR" /bin/bash <<'PROD_EOF' >> "$LOGFILE" 2>&1
set -euo pipefail

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

wget -q https://packages.microsoft.com/config/ubuntu/24.04/prod.list -O "$TMPDIR/prod.list"
ACTUAL=$(sha256sum "$TMPDIR/prod.list" | awk '{print $1}')
if [ "b1603241c9619c02611a77a663f55e726608bde079c4f559bcccdf73847a45c8" != "$ACTUAL" ]; then
  echo "SHA256 mismatch for prod.list!" >&2; exit 1
fi
mv "$TMPDIR/prod.list" /etc/apt/sources.list.d/microsoft-prod.list
PROD_EOF

  if [[ "$INSIDER_FAST" == "true" ]]; then
    log_progress "  Enabling packages.microsoft.com insiders-fast repo..."
    sudo chroot "$ROOTFS_DIR" /bin/bash <<'INSIDER_EOF' >> "$LOGFILE" 2>&1
set -euo pipefail

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

# Add insiders-fast apt source
wget -q https://packages.microsoft.com/config/ubuntu/24.04/insiders-fast.list -O "$TMPDIR/insiders-fast.list"
ACTUAL=$(sha256sum "$TMPDIR/insiders-fast.list" | awk '{print $1}')
if [ "$ACTUAL" != "6106538850c7fbb89616393aa7a9ed1094e653603a1b76dd4d7512417cfb6cf8" ]; then
  echo "SHA256 mismatch for insiders-fast.list!" >&2; exit 1
fi
mv "$TMPDIR/insiders-fast.list" /etc/apt/sources.list.d/microsoft-insiders-fast.list
INSIDER_EOF
  fi
  
  log_progress "  Adding Microsoft Azure CLI repository..."
  sudo chroot "$ROOTFS_DIR" /bin/bash <<EOF >> "$LOGFILE" 2>&1
echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ \$(lsb_release -cs) main" | tee /etc/apt/sources.list.d/azure-cli.list
EOF
  # apt update to install the keys and new repos.
  sudo chroot "$ROOTFS_DIR" apt update >> "$LOGFILE" 2>&1
  
  BASE_PACKAGES="openssh-server openssh-client systemd-resolved tpm2-tools vim bsdextrautils libtss2-dev linux-azure curl jq azure-cli systemd-boot-efi cloud-init"
  
  log_progress "    Installing base packages: $BASE_PACKAGES"
  sudo chroot "$ROOTFS_DIR" apt install -y --no-install-recommends $BASE_PACKAGES >> "$LOGFILE" 2>&1
  
  if [[ -n "$ADDITIONAL_PACKAGES" ]]; then
    PACKAGE_LIST=$(echo "$ADDITIONAL_PACKAGES" | tr ',' ' ')
    log_progress "    Installing additional packages: $PACKAGE_LIST"
    sudo chroot "$ROOTFS_DIR" apt install -y --no-install-recommends $PACKAGE_LIST >> "$LOGFILE" 2>&1
  fi

  if [[ -n "$PACKAGE_DIR" ]]; then
    log_progress "    Installing .deb packages from: $PACKAGE_DIR"
    local DEB_STAGING="/tmp/deb-packages"
    sudo mkdir -p "$ROOTFS_DIR$DEB_STAGING"
    sudo cp "$PACKAGE_DIR"/*.deb "$ROOTFS_DIR$DEB_STAGING/"
    for deb in "$ROOTFS_DIR$DEB_STAGING"/*.deb; do
      log_progress "      Queued: $(basename "$deb")"
    done
    log_progress "      Installing all .deb packages..."
    sudo chroot "$ROOTFS_DIR" bash -c "dpkg -i $DEB_STAGING/*.deb" >> "$LOGFILE" 2>&1
    log_progress "      Resolving remaining dependencies..."
    sudo chroot "$ROOTFS_DIR" apt install -f -y >> "$LOGFILE" 2>&1
    sudo rm -rf "$ROOTFS_DIR$DEB_STAGING"
  fi
  
  log_progress "  Removing unneeded firmware directories..."
  sudo rm -rf "$ROOTFS_DIR/usr/lib/firmware" "$ROOTFS_DIR/lib/firmware" 2>/dev/null || true
}

configure_services() {
  if [[ "$ALLOW_SERIAL_CONSOLE" == "true" ]]; then
    log_progress "  Configuring serial console access..."
    sudo chroot "$ROOTFS_DIR" systemctl enable serial-getty@ttyS0.service >> "$LOGFILE" 2>&1
  else
    log_progress "  Masking serial console login (use --allow-serial-console to enable)..."
    # The kernel cmdline includes console=ttyS0, which causes systemd-getty-generator
    # to automatically start serial-getty@ttyS0.service at boot even if it has not been
    # explicitly enabled. Masking the service prevents the generator from spawning it.
    sudo ln -sf /dev/null "$ROOTFS_DIR/etc/systemd/system/serial-getty@ttyS0.service"
  fi
  
  log_progress "  Disabling emergency and rescue mode shells..."
  sudo mkdir -p "$ROOTFS_DIR/etc/systemd/system/emergency.service.d"
  sudo mkdir -p "$ROOTFS_DIR/etc/systemd/system/rescue.service.d"
  sudo cp rootfs-files/emergency-disable.conf "$ROOTFS_DIR/etc/systemd/system/emergency.service.d/disable.conf"
  sudo cp rootfs-files/emergency-disable.conf "$ROOTFS_DIR/etc/systemd/system/rescue.service.d/disable.conf"
  
  # Mask systemd PCR extension services (we calculate PCR values from UKI sections only)
  log_progress "  Masking systemd PCR extension services..."
  for service in systemd-pcrphase-initrd systemd-pcrphase-sysinit systemd-pcrphase; do
    sudo ln -sf /dev/null "$ROOTFS_DIR/etc/systemd/system/${service}.service"
  done
}

configure_cloud_init() {
  log_progress "  Configuring cloud-init with hardened security policy..."
  sudo mkdir -p "$ROOTFS_DIR/etc/cloud/cloud.cfg.d"
  
  # Hardened cloud-init configuration baked into the read-only rootfs.
  # Only metadata (hostname, network) is processed. All user-data is ignored.
  # At runtime, cloud-init data files are loaded from EFI partition. The policy
  # in the rootfs controls what cloud-init is allowed to do with the data.
  sudo cp rootfs-files/cloud-init-hardened.yaml "$ROOTFS_DIR/etc/cloud/cloud.cfg.d/01-hardened.yaml"
  
  sudo mkdir -p "$ROOTFS_DIR/usr/local/bin"
  sudo cp rootfs-files/setup-etc-overlay.sh "$ROOTFS_DIR/usr/local/bin/setup-etc-overlay.sh"
  sudo chmod +x "$ROOTFS_DIR/usr/local/bin/setup-etc-overlay.sh"
  
  sudo cp rootfs-files/etc-overlay.service "$ROOTFS_DIR/etc/systemd/system/etc-overlay.service"
  
  # Install cloud-init config applicator service
  sudo cp rootfs-files/apply-cloud-init-config.sh "$ROOTFS_DIR/usr/local/bin/apply-cloud-init-config.sh"
  sudo chmod +x "$ROOTFS_DIR/usr/local/bin/apply-cloud-init-config.sh"
  sudo cp rootfs-files/apply-cloud-init-config.service "$ROOTFS_DIR/etc/systemd/system/apply-cloud-init-config.service"
  
  # Install cloud-init-local override to force it to run when we enable it
  sudo mkdir -p "$ROOTFS_DIR/etc/systemd/system/cloud-init-local.service.d"
  sudo cp rootfs-files/cloud-init-local-override.conf "$ROOTFS_DIR/etc/systemd/system/cloud-init-local.service.d/override.conf"
  
  sudo chroot "$ROOTFS_DIR" systemctl enable etc-overlay.service >> "$LOGFILE" 2>&1
  sudo chroot "$ROOTFS_DIR" systemctl enable apply-cloud-init-config.service >> "$LOGFILE" 2>&1
  sudo chroot "$ROOTFS_DIR" systemctl enable cloud-init-local.service >> "$LOGFILE" 2>&1
  sudo chroot "$ROOTFS_DIR" systemctl enable cloud-init.service >> "$LOGFILE" 2>&1  
  sudo chroot "$ROOTFS_DIR" systemctl enable cloud-config.service >> "$LOGFILE" 2>&1
  sudo chroot "$ROOTFS_DIR" systemctl enable cloud-final.service >> "$LOGFILE" 2>&1
}

create_user_account() {
  log_progress "  Creating user account and enabling SSH..."
  
  # Set password command - lock account if no password
  sudo chroot "$ROOTFS_DIR" /bin/bash <<EOF >> "$LOGFILE" 2>&1
  useradd -m -s /bin/bash $USERNAME
  if [[ -n '${PASSWORD_HASH:-}' ]]; then
    echo '$USERNAME:${PASSWORD_HASH:-}' | chpasswd -e
  elif [[ -n '${PASSWORD:-}' ]]; then
    echo '$USERNAME:${PASSWORD:-}' | chpasswd
  else
    passwd -l $USERNAME  # Lock the account
  fi
  usermod -aG sudo $USERNAME
EOF

  # Validate and sanitize username to ensure safe format
  SAFE_USERNAME=$(echo "$USERNAME" | tr -cd '[:alnum:]_-')

  # Configure sudo permissions based on --passwordless-sudo flag
  if [[ "$PASSWORDLESS_SUDO" == "true" ]]; then
    log_progress "    Configuring passwordless sudo..."
    sudo chroot "$ROOTFS_DIR" /bin/bash <<EOF >> "$LOGFILE" 2>&1
echo "$SAFE_USERNAME ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/99-$SAFE_USERNAME
chmod 0440 /etc/sudoers.d/99-$SAFE_USERNAME
EOF
  else
    log_progress "    Configuring sudo with password requirement..."
    sudo chroot "$ROOTFS_DIR" /bin/bash <<EOF >> "$LOGFILE" 2>&1
echo "$SAFE_USERNAME ALL=(ALL) ALL" > /etc/sudoers.d/99-$SAFE_USERNAME
chmod 0440 /etc/sudoers.d/99-$SAFE_USERNAME
EOF
  fi
  
  sudo chroot "$ROOTFS_DIR" /bin/bash <<EOF >> "$LOGFILE" 2>&1
systemctl enable ssh
USER_UID=\$(id -u $USERNAME)
USER_GID=\$(id -g $USERNAME)
sed -i '/tmpfs \/home tmpfs/d' /etc/fstab
echo "tmpfs /home/$USERNAME tmpfs defaults,size=512M,uid=\$USER_UID,gid=\$USER_GID,mode=0755 0 0" >> /etc/fstab
mkdir -p /etc/ssh/sshd_config.d
if [[ "$ALLOW_SSH_PASSWORD" == "true" ]]; then
  cat > /etc/ssh/sshd_config.d/60-build-settings.conf <<SSHEOF
PermitRootLogin no
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys
PasswordAuthentication yes
KbdInteractiveAuthentication yes
SSHEOF
else
  cat > /etc/ssh/sshd_config.d/60-build-settings.conf <<SSHEOF
PermitRootLogin no
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys
PasswordAuthentication no
KbdInteractiveAuthentication no
SSHEOF
fi
mkdir -p /home/$USERNAME/.ssh
chmod 700 /home/$USERNAME/.ssh
chown $USERNAME:$USERNAME /home/$USERNAME/.ssh
cat > /etc/tmpfiles.d/user-home.conf <<TMPEOF
d /home/$USERNAME/.ssh 0700 $USERNAME $USERNAME -
d /home/$USERNAME/.azure 0700 $USERNAME $USERNAME -
d /root/.azure 0700 root root -
TMPEOF
EOF

  # Install SSH public key if provided (stored in /etc/skel for tmpfs /home)
  if [[ -n "$SSH_PUBLIC_KEY" ]]; then
    log_progress "    Installing SSH public key for passwordless login..."
    sudo mkdir -p "$ROOTFS_DIR/etc/skel/.ssh"
    sudo cp "$SSH_PUBLIC_KEY" "$ROOTFS_DIR/etc/skel/.ssh/authorized_keys"
    sudo chmod 600 "$ROOTFS_DIR/etc/skel/.ssh/authorized_keys"
    
    # Also add to tmpfiles.d to restore on each boot
    sudo bash -c "cat >> '$ROOTFS_DIR/etc/tmpfiles.d/user-home.conf'" <<TMPEOF
C /home/$USERNAME/.ssh/authorized_keys 0600 $USERNAME $USERNAME - /etc/skel/.ssh/authorized_keys
TMPEOF
  fi
}

apply_rootfs_overlay() {
  if [[ -n "$ROOTFS_OVERLAY" ]]; then
    log_progress "  Applying rootfs overlay from: $ROOTFS_OVERLAY"
    
    # Handle /etc separately since it uses runtime overlay filesystem
    if [[ -d "$ROOTFS_OVERLAY/etc" ]]; then
      log_progress "    Copying /etc overlay files..."
      sudo mkdir -p "$ROOTFS_DIR/usr/local/etc-overlay-seed"
      sudo rsync -av "$ROOTFS_OVERLAY/etc/" "$ROOTFS_DIR/usr/local/etc-overlay-seed/" >> "$LOGFILE" 2>&1
    fi
    
    log_progress "    Copying overlay files preserving structure..."
    sudo rsync -av --exclude='etc' --exclude='home' "$ROOTFS_OVERLAY/" "$ROOTFS_DIR/" >> "$LOGFILE" 2>&1
  fi
}

cleanup_chroot_mounts() {
  log_progress "  Unmounting chroot filesystems..."
  sudo umount "$ROOTFS_DIR/dev" 2>/dev/null || true
  sudo umount "$ROOTFS_DIR/sys" 2>/dev/null || true  
  sudo umount "$ROOTFS_DIR/proc" 2>/dev/null || true
}

# Compress the rootfs into a squashfs file
build_squashfs() {
  log_progress "  Compressing rootfs with xz compression..."
  mksquashfs "$ROOTFS_DIR" "$SQUASHFS" -comp xz -all-root 2>&1
}

# Calculate the integrity data for the squashfs filesystem using dm-verity
generate_verity_hash() {
  log_progress "  Computing SHA256 hash tree for integrity verification..."
  veritysetup format "$SQUASHFS" "$HASHFILE" --data-block-size=4096 --hash-block-size=4096 --hash sha256 >> "$BUILD_DIR/verity.log" 2>&1
  
  detect_kernel
  
  ROOT_HASH=$(grep "Root hash:" "$BUILD_DIR/verity.log" | awk '{print $3}')
  log_progress "  Root hash: $ROOT_HASH"
}

# Find the Azure Linux kernel that was installed in the rootfs
detect_kernel() {
  log_progress "  Detecting kernel in rootfs..."
  ROOTFS_KERNEL=$(find "$ROOTFS_DIR/boot" -name "vmlinuz-*-azure" | head -1)
  if [[ -n "$ROOTFS_KERNEL" ]]; then
    AZURE_KERNEL_VERSION=$(basename "$ROOTFS_KERNEL" | sed 's/vmlinuz-//')
    log_progress "    Found Azure kernel: $AZURE_KERNEL_VERSION"
    KERNEL="$ROOTFS_KERNEL"
    log_progress "    Using Azure kernel from rootfs: $KERNEL"
    
    if [[ -d "$ROOTFS_DIR/lib/modules/$AZURE_KERNEL_VERSION" ]]; then
      log_progress "    Azure kernel modules found in rootfs"
    else
      log_progress "    Warning: No modules found for Azure kernel $AZURE_KERNEL_VERSION"
    fi
    
    KERNEL_VERSION_FOR_BUILD="$AZURE_KERNEL_VERSION"
  else
    log_progress "    No Azure kernel found, cannot continue"
    exit 1
  fi
}

# Create the raw disk image and partitions
create_disk_image() {
  log_progress "  Creating 8GB raw disk image..."
  qemu-img create -f raw "$RAW_IMG" 8G >> "$LOGFILE" 2>&1
  
  calculate_partitions
  create_partition_table
  attach_loop_device
  format_and_write_partitions
}

calculate_partitions() {
  log_progress "  Calculating partition layout..."

  # Define the size of the disk as 8GB
  SIZE_BYTES=$((8 * 1024 * 1024 * 1024))
  SIZE_MB=$((SIZE_BYTES / 1024 / 1024))
  # End of the EFI partition in MB
  EFI_END=201
  # End of the rootfs partition in MB
  ROOT_END=$((SIZE_MB - 512))
  # Range for the hash partition in MB
  HASH_START=$ROOT_END
  HASH_END=$((SIZE_MB - 1))
  log_progress "    EFI partition: 1MB - ${EFI_END}MB"
  log_progress "    Root partition: ${EFI_END}MB - ${ROOT_END}MB"  
  log_progress "    Hash partition: ${HASH_START}MB - ${HASH_END}MB"
}

create_partition_table() {
  log_progress "  Creating GPT partition table..."
  sudo parted "$RAW_IMG" --script mklabel gpt >> "$LOGFILE" 2>&1
  sudo parted "$RAW_IMG" --script mkpart EFI fat32 1MiB ${EFI_END}MiB >> "$LOGFILE" 2>&1
  sudo parted "$RAW_IMG" --script set 1 boot on >> "$LOGFILE" 2>&1
  sudo parted "$RAW_IMG" --script mkpart squashfs ext4 ${EFI_END}MiB ${ROOT_END}MiB >> "$LOGFILE" 2>&1
  sudo parted "$RAW_IMG" --script mkpart verityhash ext4 ${HASH_START}MiB ${HASH_END}MiB >> "$LOGFILE" 2>&1
}

attach_loop_device() {
  log_progress "  Attaching loop device with partition support..."
  LOOP=$(sudo losetup --find --show --partscan "$RAW_IMG")
  log_progress "  Loop device: $LOOP"
  
  sleep 2
  
  if [[ ! -b "${LOOP}p1" ]]; then
    log_progress "  Forcing partition scan..."
    sudo partx -u "$LOOP" >> "$LOGFILE" 2>&1 || true
    sleep 2
  fi
  
  if [[ ! -b "${LOOP}p1" ]] || [[ ! -b "${LOOP}p2" ]] || [[ ! -b "${LOOP}p3" ]]; then
    log_progress "  ERROR: Failed to create partition devices"
    log_progress "  Available devices:"
    ls -la /dev/loop* >> "$LOGFILE" 2>&1
    sudo losetup -d "$LOOP" >> "$LOGFILE" 2>&1 || true
    exit 1
  fi
  
  EFI_DEV="${LOOP}p1"
  ROOT_DEV="${LOOP}p2"
  HASH_DEV="${LOOP}p3"
}

format_and_write_partitions() {
  log_progress "  Formatting EFI partition..."
  sudo mkfs.vfat "$EFI_DEV" >> "$LOGFILE" 2>&1
  
  log_progress "  Writing squashfs to root partition..."
  sudo dd if="$SQUASHFS" of="$ROOT_DEV" bs=4M conv=notrunc,fsync status=none 2>> "$LOGFILE"
  sudo sync
  
  log_progress "  Writing hash tree to hash partition..."
  sudo dd if="$HASHFILE" of="$HASH_DEV" bs=4M conv=notrunc,fsync status=none 2>> "$LOGFILE"
  sudo sync
}

# Configure the kernel command line
configure_boot_parameters() {
  ROOT_UUID=$(blkid -s PARTUUID -o value "$ROOT_DEV")
  HASH_UUID=$(blkid -s PARTUUID -o value "$HASH_DEV")
  
  log_progress "  Creating kernel command line..."
  cat > "$CMDLINE" <<EOF
roothash=$ROOT_HASH \
systemd.verity_root_data=PARTUUID=$ROOT_UUID \
systemd.verity_root_hash=PARTUUID=$HASH_UUID \
root=/dev/mapper/root ro rootwait rd.auto=1 \
rd.shell=0 rd.emergency=0 \
console=tty0 console=ttyS0,115200n8 \
ima_policy=critical_data \
lockdown=confidentiality \
module.sig_enforce=1 \
kexec_load_disabled=1
EOF
}

# Package the required rootfs components into the initramfs and build the UKI
build_initramfs_and_uki() {
  log_progress "  Preparing initramfs overlay structure..."
  
  # Create overlay directory matching initramfs layout. This will be used for adding any required files
  # and service links that are needed for bootstrapping dm-verity and TPM PCR extension.
  rm -rf "$BUILD_DIR/override"
  mkdir -p "$BUILD_DIR/override"
  
  # dm-verity systemd override
  mkdir -p "$BUILD_DIR/override/etc/systemd/system/initrd-root-device.target.d"
  cp rootfs-files/verity.conf "$BUILD_DIR/override/etc/systemd/system/initrd-root-device.target.d/verity.conf"
  
  log_progress "  Building initramfs with dracut..."
  sudo dracut --force \
    --add systemd \
    --force-drivers "dm-verity hv_netvsc hv_vmbus" \
    --install "/sbin/veritysetup /usr/lib/systemd/systemd-veritysetup /usr/lib/systemd/system-generators/systemd-veritysetup-generator" \
    --include "$BUILD_DIR/override" "/" \
    --kmoddir "$ROOTFS_DIR/lib/modules/$KERNEL_VERSION_FOR_BUILD" \
    "$INITRD" "$KERNEL_VERSION_FOR_BUILD" >> "$LOGFILE" 2>&1
  INITRD_SIZE=$(du -h "$INITRD" | cut -f1)
  
  log_progress "  Building Unified Kernel Image (UKI)..."
  sudo ukify build \
    --stub="$STUB" \
    --linux="$KERNEL" \
    --initrd="$INITRD" \
    --cmdline=@"$CMDLINE" \
    --os-release="$OS_RELEASE" \
    --uname="$KERNEL_VERSION_FOR_BUILD" \
    --measure \
    --output="$UKI" > "$BUILD_DIR/ukify_output.txt" 2>&1
  
  # Append ukify output to log and save for PCR11 extraction
  cat "$BUILD_DIR/ukify_output.txt" >> "$LOGFILE"
  
  UKI_SIZE=$(du -h "$UKI" | cut -f1)
  
  log_progress "  Installing UKI to EFI partition..."
  sudo mount "$EFI_DEV" /mnt
  sudo mkdir -p /mnt/EFI/Linux
  sudo cp "$UKI" /mnt/EFI/Linux/
  sudo mkdir -p /mnt/EFI/Boot
  sudo cp "$UKI" /mnt/EFI/Boot/BootX64.efi
  sudo umount /mnt
  
  log_progress "  Cleaning up loop device..."
  sudo losetup -d "$LOOP"
}

# Convert the raw image into a vhdx
finalize_vhdx() {
  log_progress "  Converting raw image to VHDX format..."
  qemu-img convert -f raw -O vhdx "$RAW_IMG" "$VHDX_IMG" >> "$LOGFILE" 2>&1
  VHDX_SIZE=$(du -h "$VHDX_IMG" | cut -f1)
  
  log_progress "  Calculating expected TPM PCR values..."
  
  # Calculate PCR4 (boot loader measurements)
  ./scripts/calc_pcr4.sh "$UKI" > "$BUILD_DIR/pcr4.txt" 2>> "$LOGFILE"
  
  # Calculate PCR11 (UKI section measurements)
  ./scripts/calc_pcr11.sh "$UKI" > "$BUILD_DIR/pcr11.txt" 2>> "$LOGFILE"
  
  # Combine both PCR4 and PCR11 into a single file
  {
    echo "=========================================="
    echo "Expected TPM PCR Values"
    echo "=========================================="
    echo ""
    echo "PCR 4 - Boot Loader Code and Configuration"
    echo "-------------------------------------------"
    tail -n 7 "$BUILD_DIR/pcr4.txt"
    echo ""
    echo "PCR 11 - UKI Section Measurements"
    echo "-------------------------------------------"
    tail -n 7 "$BUILD_DIR/pcr11.txt"
  } > "$OUT_DIR/calculated_pcrs.txt"
}

# Parse command-line arguments
parse_arguments() {
  USERNAME=""
  VHDX_FILENAME=""
  ADDITIONAL_PACKAGES=""
  ROOTFS_OVERLAY=""
  PACKAGE_DIR=""
  SSH_PUBLIC_KEY=""
  SET_PASSWORD="false"
  PASSWORDLESS_SUDO="false"
  INSIDER_FAST="false"
  ALLOW_SSH_PASSWORD="false"
  ALLOW_SERIAL_CONSOLE="false"
  VERBOSE="false"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --username)
        USERNAME="$2"
        shift 2
        ;;
      --image)
        VHDX_FILENAME="$2"
        shift 2
        ;;
      --packages)
        ADDITIONAL_PACKAGES="$2"
        shift 2
        ;;
      --ssh-key)
        SSH_PUBLIC_KEY="$2"
        shift 2
        ;;
      --rootfs-overlay)
        ROOTFS_OVERLAY="$2"
        shift 2
        ;;
      --package-dir)
        PACKAGE_DIR="$2"
        shift 2
        ;;
      --password)
        SET_PASSWORD="true"
        shift
        ;;
      --passwordless-sudo)
        PASSWORDLESS_SUDO="true"
        shift
        ;;
      --insiders-fast)
        INSIDER_FAST="true"
        shift
        ;;
      --allow-ssh-password)
        ALLOW_SSH_PASSWORD="true"
        shift
        ;;
      --allow-serial-console)
        ALLOW_SERIAL_CONSOLE="true"
        shift
        ;;
      --password-hash)
        PASSWORD_HASH="$2"
        shift 2
        ;;
      --verbose-output)
        VERBOSE="true"
        shift
        ;;
      *)
        echo "Unknown option: $1"
        usage
        ;;
    esac
  done

  # Validate required arguments
  if [[ -z "$USERNAME" || -z "$VHDX_FILENAME" ]]; then
    usage
  fi
  if [[ "$SET_PASSWORD" == "true" && -n "${PASSWORD_HASH:-}" ]]; then
    echo "Error: --password and --password-hash are mutually exclusive."
    exit 1
  fi
}

# Prompt for user password securely
prompt_for_password() {
  echo -n "Enter password for user '$USERNAME': "
  read -s PASSWORD
  echo
  echo -n "Confirm password: "
  read -s PASSWORD_CONFIRM
  echo

  if [[ "$PASSWORD" != "$PASSWORD_CONFIRM" ]]; then
    echo "Error: Passwords do not match"
    exit 1
  fi

  if [[ -z "$PASSWORD" ]]; then
    echo "Error: Password cannot be empty"
    exit 1
  fi

  if [[ "$PASSWORD" == *"'"* ]]; then
    echo "Error: Password must not contain single quotes (')"
    exit 1
  fi
}

# ============================================================================
# Main Script
# ============================================================================

parse_arguments "$@"

BUILD_DIR="./build"
OUT_DIR="./out"
ROOTFS_DIR="./rootfs"
RAW_IMG="$BUILD_DIR/${VHDX_FILENAME%.vhdx}.raw"
VHDX_IMG="$OUT_DIR/$VHDX_FILENAME"
SQUASHFS="$BUILD_DIR/rootfs.squashfs"
HASHFILE="$BUILD_DIR/rootfs.hash"
UKI="$BUILD_DIR/uki.efi"
CMDLINE="$BUILD_DIR/cmdline.txt"
INITRD="$BUILD_DIR/initrd-verity.img"
KERNEL="/boot/vmlinuz-$(uname -r)"
OS_RELEASE="/etc/os-release"
STUB="$ROOTFS_DIR/usr/lib/systemd/boot/efi/linuxx64.efi.stub"
LOGFILE="$BUILD_DIR/build.log"

# Create build directory and log file
rm -rf "$BUILD_DIR" 2>/dev/null || true
mkdir -p "$BUILD_DIR"
mkdir -p "$OUT_DIR"

# In verbose mode, tee all output (stdout + stderr) to both the console and the log
# file. LOGFILE is then changed to /dev/stdout so every ">> $LOGFILE" redirect also
# flows through the same tee pipe rather than writing directly to the file.
if [[ "$VERBOSE" == "true" ]]; then
  exec > >(tee -a "$LOGFILE") 2>&1
  LOGFILE="/dev/stdout"
  log_progress() { echo "$@"; }
fi

log_progress "=========================================="
log_progress "CVM image build started"
log_progress "=========================================="
log_progress "Target VHDX: $VHDX_FILENAME"
log_progress "Username: $USERNAME"
if [[ -n "$ADDITIONAL_PACKAGES" ]]; then
  log_progress "Additional packages: $ADDITIONAL_PACKAGES"
fi
if [[ -n "$ROOTFS_OVERLAY" ]]; then
  log_progress "Rootfs overlay: $ROOTFS_OVERLAY"
fi
if [[ -n "$PACKAGE_DIR" ]]; then
  log_progress "Package directory: $PACKAGE_DIR"
fi
log_progress "Build log: $BUILD_DIR/build.log"
log_progress "=========================================="
log_progress ""

if [[ -n "${PASSWORD_HASH:-}" ]]; then
  log_progress "Using provided password hash for user account"
elif [[ "$SET_PASSWORD" == "true" ]]; then
  prompt_for_password
else 
  PASSWORD=""
  if [[ "$ALLOW_SSH_PASSWORD" == "true" ]]; then
    echo "Error: --allow-ssh-password requires --password or --password-hash to be set."
    exit 1
  fi
  if [[ "$ALLOW_SERIAL_CONSOLE" == "true" ]]; then
    echo "Error: --allow-serial-console requires --password or --password-hash to be set."
    exit 1
  fi
  if [[ -z "$SSH_PUBLIC_KEY" ]]; then
    echo "WARNING: Building VM with no password and no SSH key."
    echo "         You will NOT be able to log in to this VM!"
  fi
fi

log_progress ">>> Installing dependencies..."
install_dependencies

log_progress ">>> Cleaning build environment..."
prepare_build_environment

log_progress ">>> Preparing rootfs..."
create_ubuntu_rootfs
build_squashfs

log_progress ">>> Generating integrity data..."
generate_verity_hash

log_progress ">>> Preparing raw disk image..."
create_disk_image

log_progress ">>> Generating kernel command line..."
configure_boot_parameters

log_progress ">>> Building initramfs and UKI..."
build_initramfs_and_uki

log_progress ">>> Converting raw disk to vhdx..."
finalize_vhdx

# Output final summary
log_progress ""
log_progress "=========================================="
log_progress "Build Complete"
log_progress "=========================================="
log_progress "VHDX image: $VHDX_IMG ($VHDX_SIZE)"
log_progress "Build artifacts in: $BUILD_DIR/"
log_progress "DM-verity root hash: $ROOT_HASH"
log_progress ""
if [[ "$VERBOSE" == "true" ]]; then
  cat "$OUT_DIR/calculated_pcrs.txt"
else
  cat "$OUT_DIR/calculated_pcrs.txt" | tee -a "$LOGFILE"
fi
