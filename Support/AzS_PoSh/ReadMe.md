# AzS-PoSh-Environment.ps1 #

![](https://github.com/Azure/AzureStack-Tools/blob/master/Support/AzS_PoSh/Media/AzsPoSh.gif?raw=true)


Script to setup AzureStack PowerShell Enviroment

Via UI or CLI the script will insure Azure Stack PowerShell modules are running at the proper version. Build AzureStack endpoint environment variables from supplied JSON file. Download and extract AzureStack-Tools-master Toolkit. Builds a function called AzSLoadTools that imports modules in proper order. If no parameters are supplied the script will default to prompting user via GUI for needed parameters.

## AzSPathToStampJSON ##
Path to AzureStackStampInformation.json file

-  "C:\Users\AzureStackAdmin\Desktop\AzureStackStampInformation.json"

## AzSToolsPath ##
Path to AzureStack-Tools-master folder 

- "C:\Users\AzureStackAdmin\Desktop\master\AzureStack-Tools-master"

## Example Use ##
	.\AzS-PS-Environment.ps1 -AzSPathToStampJSON "C:\Users\AzureStackAdmin\Desktop\AzureStackStampInformation.json" -AzSToolsPath "C:\Users\AzureStackAdmin\Desktop\master\AzureStack-Tools-master"
