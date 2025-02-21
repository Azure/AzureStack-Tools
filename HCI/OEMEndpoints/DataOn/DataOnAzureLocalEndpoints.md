# DataOn required SBE endpoints for Azure Local deployments

This page provides a comprehensive overview of the necessary endpoints for deploying Azure Local using the DataOn solution. These URLs are maintained by the OEM. Please contact with your OEM provider if these URLs have been updated

**This list last update is from February 21st, 2025**

| Id | OEM SBE package URL | Endpoint URL                                                           | Port | Notes                                                    | Arc gateway support | Required for                 |
|----|---------------------|------------------------------------------------------------------------|------|----------------------------------------------------------|---------------------|------------------------------|
| 1  | DataOn              | dataonsbe.blob.core.windows.net/sbe-manifest/SBE_Discovery_DataON.xml  | 443  | Enable direct download of future SBE updates from DataON | No                  | Deployment & Post deployment |
| 2  | DataOn              | aka.ms/AzureStackSBEUpdate/DataON                                      | 443  | Microsoft redirection to the explicit DataON SBE endpoint| Yes                 | Deployment & Post deployment |

