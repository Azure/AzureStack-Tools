# HPE required endpoints for Azure Local deployments

This page provides a comprehensive overview of the necessary endpoints for deploying Azure Local using HPE solutions. These URLs are maintained by the OEM hardware vendor. Please contact with your OEM provider if these URLs need to be updated.

Each hardware vendor provided [Solution Builder Extension (SBE)](https://learn.microsoft.com/en-us/azure/azure-local/update/solution-builder-extension) will require some minimal endpoints to allow for discovery and download of [SBE](https://learn.microsoft.com/en-us/azure/azure-local/update/solution-builder-extension) updates for your solution.

Refer to the table in the following document to determine if your solution supports an SBE as well is to review SBE release notes or and other documentation: https://learn.microsoft.com/en-us/azure/azure-local/update/solution-builder-extension?view=azloc-24113#identify-a-solution-builder-extension-update-for-your-hardware

In addition to [SBE](https://learn.microsoft.com/en-us/azure/azure-local/update/solution-builder-extension) endpoints, some OEM hardware vendors will require additional endpoints for there specific use cases as noted below.

**Last updated on March 19, 2025**

| Id | Endpoint Description | Endpoint URL                                                           | Port | Notes                                                    | Arc gateway support | Required for                 |
|----|---------------------|------------------------------------------------------------------------|------|----------------------------------------------------------|---------------------|------------------------------|
| 1  | SBE Manifest endpoint (all)   | h41380.www4.hpe.com/hpe/microsoft/SBE_Discovery_HPE.xml  | 443  | Enables discovery and confirmation of validity for SBE updates from OEM.  Used by all HPE solutions. | No                  | Deployment & Post deployment |
| 2  | SBE Manifest endpoint (some models)   | h41380.www4.hpe.com/hpe/SBE/SBE_Discovery_HPE.xml  | 443  | Enables discovery and confirmation of validity for SBE updates from OEM. Only used by HPE DL380 Gen11 Integrated Systems. | No                  | Deployment & Post deployment |
| 3  | SBE Manifest redirection link (all)     | aka.ms/AzureStackSBEUpdate/HPE                                   | 443  | Microsoft redirection to the explicit OEM SBE manifest endpoint. | No                 | Deployment & Post deployment |
| 4  | SBE Manifest redirection link (some models)    | aka.ms/AzureStackSBEUpdate/HPE-ProLiant-Standard                                    | 443  | Microsoft redirection to the explicit OEM SBE manifest endpoint. Only used by HPE DL380 Gen11 Integrated Systems. | No                 | Deployment & Post deployment |


