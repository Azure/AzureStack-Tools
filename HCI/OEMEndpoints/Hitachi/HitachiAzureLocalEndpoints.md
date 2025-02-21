# Hitachi required SBE endpoints for Azure Local deployments

This page provides a comprehensive overview of the necessary endpoints for deploying Azure Local using the Hitachi solutions. These URLs are maintained by the OEM. Please contact with your OEM provider if these URLs have been updated

**This list last update is from February 21st, 2025**

| Id | OEM SBE package URL | Endpoint URL                                                                    | Port | Notes                                                      | Arc gateway support | Required for                 |
|----|---------------------|---------------------------------------------------------------------------------|------|----------------------------------------------------------  |---------------------|------------------------------|
| 1  | Hitachi             | download.hitachivantara.com/ucpasbe/xml/SBE_Discovery_HitachiVantara.xml        | 443  | Enable direct download of future SBE updates from Hitachi  | No                  | Deployment & Post deployment |
| 2  | Hitachi             | aka.ms/AzureStackSBEUpdate/HitachiVantara                                       | 443  | Microsoft redirection to the explicit Hitachi SBE endpoint | Yes                 | Deployment & Post deployment |

