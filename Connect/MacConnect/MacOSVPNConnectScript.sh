#!/bin/sh



#Default arg values
vpnName="AzureStack"
authAccount="Administrator"
domain="azurestack.local"
natIP=""

#Argument Parsing
while [[ $# -gt 0 ]]
do 
        argName="$1"
        case $argName in 
                --natIP|-natIP|--natip|-natip)
                natIP="$2"
                shift;;
                --vpnaccount|-vpnaccount)
                authAccount="$2"
                shift;;
                --vpnname|-vpnname)
                vpnName="$2"
                shift;;
                --domain|-domain)
                domain="$2"
                shift;;
                *)
                ;;
        esac
        shift
done

# Input VPN Account Password
echo "Enter the password for the Azure Stack $authAccount account:" 
read -s password
echo


#Create AzureStack VPN connection
function createAzureStackVPN {
echo "Creating your Azure Stack VPN Connection with name $vpnName..."
/usr/bin/env osascript <<-EOF
tell application "System Preferences"
        reveal pane "Network"
        activate
        tell application "System Events"
                tell process "System Preferences"
                        tell window 1
                                delay 1
                                click button "Add Service"
                                tell sheet 1
                                        click pop up button 1
                                        click menu item "VPN" of menu 1 of pop up button 1
                                        delay 1
                                        click pop up button 2
                                        click menu item "L2TP over IPSec" of menu 1 of pop up button 2
                                        delay 1
                                        set value of text field 0 to "$vpnName"
                                        delay 1
                                        click button 2
                                end tell
                                tell group 1
                                        set value of text field 1 to "$natIP"
                                        set value of text field 2 to "$authAccount"
                                        click button 1
                                end tell
                                tell sheet 1
                                        delay 1
                                        set focused of text field 1 to true
                                        set value of text field 1 to "$password"
                                        set focused of text field 2 to true
                                        set value of text field 2 to "$password"
                                        set focused of text field 3 to true
                                        click button 4                                       
                                end tell
                                delay 1
                                click button 7
                        end tell
                end tell
        end tell
end tell
tell application "System Preferences" to quit
EOF

#Add Routes for AzureStack
#route -nv add -net 192.168.102.0/27  -interface $vpnName
#route -nv add -net 192.168.105.0/27  -interface $vpnName

}

#Connect to AzureStack 
function connectAzureStackVPN {
echo "Attempting connection of the $vpnName VPN..."
/usr/bin/env osascript <<-EOF
tell application "System Events"
        tell current location of network preferences
                set VPN to service "$vpnName"
                if exists VPN then connect VPN
        end tell
end tell
EOF
}


function importAzureStackRootCertificate {
        #Access certificate share and import certificate to trustedRoot of login keychain
        certDir=./azurestackcert
        mkdir $certDir
        echo $password | mount -t smbfs //Administrator@MAS-CON01.azurestack.local/CertificateShare $certDir
        sudo security add-trusted-cert -d -r trustRoot -k $HOME/Library/Keychains/login.keychain $certDir/CA.cer
        umount $certDir
        rm -r $certDir
        return 0
}

#Check whether a vpn configuration already exists
testVPNConnectionExists=`scutil --nc list`
if [[ $testVPNConnectionExists == *"$vpnName"* ]]
then 
        echo "A VPN connection with the name $vpnName already exists."
else
        createAzureStackVPN
        sleep 3
        testVPNConnectionExists=`scutil --nc list`
        if [[ $testVPNConnectionExists == *"$vpnName"* ]]
        then
                echo "VPN connection successfully created."
        else
                echo "VPN connection could not be created successfully."
                exit 1
        fi
fi

#Attempt VPN connection and wait for it to be established
connectAzureStackVPN
for i in `seq 1 10`;
do
        sleep 1
        status=`scutil --nc list | grep $vpnName`
        if [[ $status == *"Connected"* ]]
        then 
                break
        fi
        echo "Waiting for Azure Stack VPN connection to be established..."
        if [[ "$i" -eq  "10" ]]
        then 
                echo "VPN connection could not be established. Make sure the IP address is specified correctly and that it is accessible over the network."
                exit 1
        fi
done 
echo "VPN connected successfully."

#Check for SSL certificate verification failure when connecting to portal
curl "https://portal.$domain/" &> /dev/null
certPresent=$?
if [[ $certPresent -eq 0 ]]; then
        echo "Certificate is already trusted."
else
        echo "Certificate needs to be imported. Accessing certificate share..."
        certImported=$(importAzureStackRootCertificate)
        if [[ $certImported -eq 0 ]]; then
                echo "Certificate imported."
        else
                echo "Certificate could not be imported successfully. Check that the certificate fileshare is available."
        fi
fi


echo "Azure Stack VPN connection successful"

