
# AzureStack Canary validator
Canary validator provides a breadth customer experience with the Azure Stack deployment. It tries to exercise the various customer scenarios/usecases on the deployment. 

Instructions are relative to the .\CanaryValidator directory.
Canary can be invoked either as Service Administrator or Tenant Administrator.

# Download Canary
```powershell
invoke-webrequest https://github.com/Azure/AzureStack-Tools/archive/master.zip -OutFile master.zip
expand-archive master.zip -DestinationPath . -Force
cd AzureStack-Tools-master\CanaryValidator
```

# To execute Canary as Tenant Administrator
```powershell
# Install-Module AzureRM -RequiredVersion 1.2.8 -Force
# Install-Module AzureStack -RequiredVersion 1.2.8 -Force
$TenantAdminCreds =  New-Object System.Management.Automation.PSCredential "<Tenant Admin username>", (ConvertTo-SecureString "<Tenant Admin password>" -AsPlainText -Force)
$ServiceAdminCreds =  New-Object System.Management.Automation.PSCredential "<Service Admin username>", (ConvertTo-SecureString "<Service Admin password>" -AsPlainText -Force)
.\Canary.Tests.ps1  -AADTenantID "<TenantID from Azure Active Directory>"  -AdminArmEndpoint "<Administrative ARM endpoint>" -ServiceAdminCredentials $ServiceAdminCreds -TenantArmEndpoint "<Tenant ARM endpoint>" -TenantAdminCredentials $TenantAdminCreds
```

# To execute Canary as Service Administrator
```powershell
# Install-Module AzureRM -RequiredVersion 1.2.8 -Force
# Install-Module AzureStack -RequiredVersion 1.2.8 -Force
$ServiceAdminCreds =  New-Object System.Management.Automation.PSCredential "<Service Admin username>", (ConvertTo-SecureString "<Service Admin password>" -AsPlainText -Force)
.\Canary.Tests.ps1 -AADTenantID "<TenantID from Azure Active Directory>"  -AdminArmEndpoint "<Administrative ARM endpoint>"  -ServiceAdminCredentials $ServiceAdminCreds -TenantArmEndpoint "<Tenant ARM endpoint>" 
```
# Reading the results & logs
Canary generates log files in the TMP directory ($env:TMP). The logs can be found under the directory "CanaryLogs[DATETIME]". There are two types of logs generated, a text log and a JSON log. JSON log provides a quick and easy view of all the usecases and their corresponding results. Text log provides a more detailed output of each usecase execution, its output and results.

Each usecase entry in the JSON log consists of the following fields.
- Name
- Description
- StartTime
- EndTime
- Result
- Exception (in case a scenario fails)

The exception field is helpful to debug failed usecases.  

