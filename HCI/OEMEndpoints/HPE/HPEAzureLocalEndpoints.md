# HPE required SBE endpoints for Azure Local deployments

This page provides a comprehensive overview of the necessary endpoints for deploying Azure Local using the HPE solutions. These URLs are maintained by the OEM. Please contact with your OEM provider if these URLs have been updated

**This list last update is from February 21st, 2025**

| Id | OEM SBE package URL | Endpoint URL                                                                    | Port | Notes                                                      | Arc gateway support | Required for                 |
|----|---------------------|---------------------------------------------------------------------------------|------|----------------------------------------------------------  |---------------------|------------------------------|
| 1  | HPE                 | h41380.www4.hpe.com/hpe/microsoft/SBE_Discovery_HPE.xml                         | 443  | Enable direct download of future SBE updates from HPE      | No                  | Deployment & Post deployment |
| 1  | HPE                 | h41380.www4.hpe.com/hpe/SBE/SBE_Discovery_HPE.xml                               | 443  | Enable direct download of future SBE updates from HPE      | No                  | Deployment & Post deployment |
| 3  | HPE                 | aka.ms/AzureStackSBEUpdate/HPE                                                  | 443  | Microsoft redirection to the explicit HPE SBE endpoint     | Yes                 | Deployment & Post deployment |
| 4  | HPE                 | aka.ms/AzureStackSBEUpdate/HPE-ProLiant-Standard                                | 443  | Microsoft redirection to the explicit HPE SBE endpoint     | Yes                 | Deployment & Post deployment |


