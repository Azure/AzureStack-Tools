# Support Scripts #
Scripts created to be run on the HLH, DVM, ASDK HOST or Jumpbox from an administrative powershell session. These scripts are referenced from within the Release Notes for Azure Stack Integrated System as well as Azure Stack Development Kit (ASDK) to solve or workaround identified Known Issues.

The script scripts will contain information on relevancy for both build and deployment type as well as intended use and overall environmen impact (as needed).

##  Available Support Scripts: ##
-  Start-ResourceSynchronization.ps1 (applies to both Integraded System and ASDK; relevant build(s): 1802)

- Get-OfferQuota.ps1
-Ex: 
-Get-OfferQuota.ps1 -AdminARMEndpoint "https://adminmanagement.Region.FQDN" -SubscriptionID "1111111-2222-33333-4444-555555555" (To get Resource Providers aggregated quota for specific subscription in CSV format)
-Get-OfferQuota.ps1 -AdminARMEndpoint "https://adminmanagement.Region.FQDN" (To get Resource Providers aggregated quota for all tenant subscriptions in CSV format)
