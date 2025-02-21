# Dell required SBE endpoints for Azure Local deployments

This page provides a comprehensive overview of the necessary endpoints for deploying Azure Local using the Dell solutions. These URLs are maintained by the OEM. Please contact with your OEM provider if these URLs have been updated

**This list last update is from February 21st, 2025**

| Id | OEM SBE package URL | Endpoint URL                                                                    | Port | Notes                                                    | Arc gateway support | Required for                 |
|----|---------------------|---------------------------------------------------------------------------------|------|----------------------------------------------------------|---------------------|------------------------------|
| 1  | Dell                | downloads.dell.com/folderdatastore/apex-cp-azure/prod01/SBE_Discovery_Dell.xml  | 443  | Enable direct download of future SBE updates from Dell   | No                  | Deployment & Post deployment |
| 2  | Dell                | aka.ms/AzureStackSBEUpdate/Dell                                                 | 443  | Microsoft redirection to the explicit Dell SBE endpoint  | Yes                 | Deployment & Post deployment |

