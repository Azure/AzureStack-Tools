# Hitachi required endpoints for Azure Local deployments

This page provides a comprehensive overview of the necessary endpoints for deploying Azure Local using HitachiVantara solutions. These URLs are maintained by the OEM hardware vendor. Please contact with your OEM provider if these URLs need to be updated.

Each hardware vendor provided [Solution Builder Extension (SBE)](https://learn.microsoft.com/en-us/azure/azure-local/update/solution-builder-extension) will require some minimal endpoints to allow for discovery and download of [SBE](https://learn.microsoft.com/en-us/azure/azure-local/update/solution-builder-extension) updates for your solution.

Refer to the table in the following document to determine if your solution supports an SBE as well is to review SBE release notes or and other documentation: https://learn.microsoft.com/en-us/azure/azure-local/update/solution-builder-extension?view=azloc-24113#identify-a-solution-builder-extension-update-for-your-hardware

In addition to [SBE](https://learn.microsoft.com/en-us/azure/azure-local/update/solution-builder-extension) endpoints, some OEM hardware vendors will require additional endpoints for there specific use cases as noted below.

**Last updated on March 19, 2025**

| Id | Endpoint Description | Endpoint URL                                                           | Port | Notes                                                    | Arc gateway support | Required for                 |
|----|---------------------|------------------------------------------------------------------------|------|----------------------------------------------------------|---------------------|------------------------------|
| 1  | SBE Manifest endpoint    | download.hitachivantara.com/ucpasbe/xml/SBE_Discovery_HitachiVantara.xml  | 443  | Enables discovery and confirmation of validity for SBE updates from OEM | No                  | Deployment & Post deployment |
| 2  | SBE Manifest redirection link     | aka.ms/AzureStackSBEUpdate/HitachiVantara                                   | 443  | Microsoft redirection to the explicit OEM SBE manifest endpoint. | No                 | Deployment & Post deployment |

