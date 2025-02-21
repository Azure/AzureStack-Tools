# Lenovo required SBE endpoints for Azure Local deployments

This page provides a comprehensive overview of the necessary endpoints for deploying Azure Local using the Lenovo solutions. These URLs are maintained by the OEM. Please contact with your OEM provider if these URLs have been updated

**This list last update is from February 21st, 2025**

| Id | OEM SBE package URL | Endpoint URL                                                                    | Port | Notes                                                      | Arc gateway support | Required for                 |
|----|---------------------|---------------------------------------------------------------------------------|------|----------------------------------------------------------  |---------------------|------------------------------|
| 1  | Lenovo              | thinkagile.lenovo.com/MX/SBE/SBE_Discovery_Lenovo.xml                           | 443  | Enable direct download of future SBE updates from Lenovo   | No                  | Deployment & Post deployment |
| 3  | Lenovo              | aka.ms/AzureStackSBEUpdate/Lenovo                                               | 443  | Microsoft redirection to the explicit Lenovo SBE endpoint  | Yes                 | Deployment & Post deployment |


