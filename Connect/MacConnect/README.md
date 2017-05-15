# VPN Connection Script for Mac Clients

These scripts enable you to connect Mac clients to your Azure Stack One Node environment. 

## Certificate Share Creation
As a prerequisite, you need to export your root certificate and make it available on a file share. 

1. Log into the MAS-Con01 VM in your Azure Stack environment.
2. Execute the following command as an Administrator to export your certificate to a share: 
```
./CertShareCreation.ps1 
```
3. The script will request the credentials for AzureStack\Administrator. Use the credentials you gave when you deployed the environment.
4. Make a note of the outputted NAT IP address - this will be used to configure the Mac clients.

This script does the following:
* Connects to the BGPNAT01 VM and retrieves it's external IP Address
* Connects to the CA01 VM to retrieve the root certificate 
* Creates a fileshare on the Con01 VM to make the certificate accessible to external clients. Share access is granted to AzureStack\Administrator.


## Mac Client Configuration

For Mac clients running OSX, execute the following in this directory:
```
sudo sh ./OSXVPNConnectScript.sh --natIP <NatIP>
```

For Mac clients running MacOS, execute:
```
sudo sh ./MacOSVPNConnectScript.sh --natIP <NatIP>
```

A password will be requested for the VPN Administrator account. This will be the password you used when you deployed the environment.

*Note*: This script uses UI automation and will request permission to use accessibility features to configure the VPN connection. *For security reasons, make sure that these permissions are removed after you finish running the script.*

This script does the following items:
* Creates a new L2TP VPN connection named AzureStack to your Azure Stack environment
* Connects to the created VPN Creation
* Retrieves the certificate needed to trust Azure Stack endpoints

After completion of the script, you should be able to access the portal at https://portal.azurestack.local. 

Note: 

## Routes
In some cases, you may need to create routes on your client to correctly access the Azure Stack environment. 

Run the following commands to create the routes after creating the VPN interface:
```
route -nv add -net 192.168.102.0/27  -interface AzureStack
route -nv add -net 192.168.105.0/27  -interface AzureStack
```