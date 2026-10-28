# SEAM loader UEFI variable override

Instructions for applying and removing the SEAM loader SVN firmware override on an Intel TDX machine during BIOS setup. This override must be applied for TDX to work correctly on Azure Local.

## What the override does

The script applies the UEFI variable `VAR_UEFI_SEAM_LOADER_SVN` in namespace `{ffe88134-0c2f-4f69-a9ac-d8f5ad185e23}` with the one-byte value `255`. This is paired with disabling the BIOS setting "TDX Secure Arbitration Mode Loader (SEAM Loader)" so Hyper-V can use its software-provided TDX module and SEAM loader.

**Note: This setting persists on each machine independently of OS redeployment. Record the nodes on which the override was applied and remove it explicitly when it is no longer needed. If you are removing Azure Local from your hardware, you must remove the override or you may experience failures to run TDX on future Linux deployments.**

## Prerequisites

- You must configure the required TDX and SGX BIOS settings, including disabling the BIOS SEAM Loader option - set `TDX Secure Arbitration Mode Loader (SEAM Loader)` to `Disabled`.
- You must have access to PowerShell on the cluster nodes (e.g. by deploying Azure Local).

## Apply the override

1. Open elevated PowerShell on the TDX node and change to the folder containing the script.
2. Apply the standard TDX override:

   ```powershell
   .\OverrideSeamLoaderSvnFirmware.ps1 -Operation apply
   ```

3. Confirm the script reports that the override was applied and that the variable value is `255`. Optionally read the variable explicitly:

   ```powershell
   .\OverrideSeamLoaderSvnFirmware.ps1 -Operation read
   ```

The read operation prints the variable name and stored byte value. Repeat on every node in your Azure Local cluster.

## Uninstalling Azure Local

If you are uninstalling Azure Local, then you should remove the override on your system. To remove the override, use the script's supported remove operation:

```powershell
.\OverrideSeamLoaderSvnFirmware.ps1 -Operation remove
```

Confirm that the script reports successful removal. Run this on each machine where the override was applied. Removal affects only the UEFI variable; it does not change the BIOS SEAM Loader setting. Coordinate any BIOS reconfiguration separately using the hardware vendor's supported process.
