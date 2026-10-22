# Azure Local deployment required endpoints for US Gov Arizona

**Last updated: October 19, 2026.**

This page provides a comprehensive overview of the necessary endpoints for deploying Azure Local in the US Gov Arizona region. It outlines the specific URLs, ports and protocols that must be accessible during the deployment process to ensure successful integration with Azure services. The document serves as a crucial resource for IT professionals and system administrators who are preparing to deploy Azure Local solutions, offering detailed guidance on network configuration and external connectivity requirements. By adhering to the listed endpoints, users can facilitate a smooth deployment process, ensuring that their Azure Local environment is properly connected and functional within the US Gov Arizona region.

| Id | Azure Local Component | Endpoint URL | Port | Notes | Arc gateway support | Required for |
|----|-----------------------|--------------|------|-------|---------------------|--------------|
| 1 | Azure Local AKS infra | *.blob.storage.azure.net | 443 | To access blob storage. | No | Deployment & Post deployment |
| 2 | Azure Local AKS infra | *.data.mcr.microsoft.com | 443 | Microsoft Artifact Registry CDN locations. | No | Deployment & Post deployment |
| 3 | Azure Local AKS infra | *.prod.do.dsp.mp.microsoft.com | 443 | Used for AKS Arc VHD image download and update. | No | Deployment & Post deployment |
| 4 | Azure Local AKS infra | aszk8snetworking.azurecr.io | 443 | Used for official Microsoft artifacts such as container images. | No | Deployment & Post deployment |
| 5 | Azure Local AKS infra | azurearcfork8s.azurecr.io | 443 | Used for official Microsoft artifacts such as container images. | No | Deployment & Post deployment |
| 6 | Azure Local AKS infra | azurearcfork8sdev.azurecr.io | 443 | Used for official Microsoft artifacts such as container images. | No | Deployment & Post deployment |
| 7 | Azure Local AKS infra | azurewatsonanalysis-prod.core.windows.net | 443 | Used for metrics and monitoring telemetry traffic. | No | Deployment & Post deployment |
| 8 | Azure Local AKS infra | ecpacr.azurecr.io | 443 | Used for official Microsoft artifacts such as container images. | No | Deployment & Post deployment |
| 9 | Azure Local AKS infra | edgesupprd.trafficmanager.net | 443 | Remote Support Extension | No | Deployment & Post deployment |
| 10 | Azure Local AKS infra | hciarcvmscontainerregistry.azurecr.io | 443 | For Arc VM container registry on Azure Local 23H2. | No | Deployment & Post deployment |
| 11 | Azure Local AKS infra | hciarcvmsstorage.z13.web.core.windows.net | 443 | Storage account for stack-hci-vm CLI extension files. | No | Deployment & Post deployment |
| 12 | Azure Local AKS infra | https://usgovarizona.obo.arc.azure.us | 8084 | Requested Arizona counterpart for the post-deployment AKS endpoint; service availability on port 8084 is unverified. | No | Post Deployment |
| 13 | Azure Local AKS infra | hybridaks.azurecr.io | 443 | Used for official Microsoft artifacts such as container images. | No | Deployment & Post deployment |
| 14 | Azure Local AKS infra | hybridaksstorage.z13.web.core.windows.net | 443 | AKS Azure Local static website hosted in Azure Storage. | No | Deployment & Post deployment |
| 15 | Azure Local AKS infra | linuxgeneva-microsoft.azurecr.io | 443 | Used for official Microsoft artifacts such as container images. | No | Deployment & Post deployment |
| 16 | Azure Local AKS infra | mcr.microsoft.com | 443 | Microsoft Artifact Registry Endpoint and discovery UI | No | Deployment & Post deployment |
| 17 | Azure Local AKS infra | sts.windows.net | 443 | For Cluster Connect and Custom Location-based scenario. | No | Deployment & Post deployment |
| 18 | Azure Local AKS infra | usgovarizona.dp.kubernetesconfiguration.azure.us | 443 | Required for AKS. | No | Deployment |
| 19 | Azure Local ARB infra | arcplatformcliextprod.blob.core.windows.net | 443 | Used to deploy Azure Resource Bridge extensions. | No | Deployment & Post deployment |
| 20 | Azure Local ARB infra | arcplatformcliextprod.z13.web.core.windows.net | 443 | Used to deploy Azure Resource Bridge extensions. | No | Deployment & Post deployment |
| 21 | Azure Local ARB infra | k8connecthelm.azureedge.net | 443 | Deploy Azure Arc agent. | No | Deployment & Post deployment |
| 22 | Azure Local ARB infra | k8sconnectcsp.azureedge.net | 443 | Required for Custom Location. | No | Deployment & Post deployment |
| 23 | Azure Local ARB infra | kvamanagementoperator.azurecr.io | 443 | Pull artifacts for Appliance managed components. | No | Deployment & Post deployment |
| 24 | Azure Local ARB infra | msk8s.api.cdp.microsoft.com | 443 | Download product catalog, product bits, and OS images from SFS. | No | Deployment & Post deployment |
| 25 | Azure Local ARB infra | msk8s.sb.tlu.dl.delivery.mp.microsoft.com | 443 | Download the Arc Resource Bridge OS images. | No | Deployment & Post deployment |
| 26 | Azure Local ARB infra | packages.microsoft.com | 443 | Download Linux installation package. | No | Deployment & Post deployment |
| 27 | Azure Local ARB infra | prod5.prod.hot.ingest.monitor.core.windows.net | 443 | Periodically sends Microsoft required diagnostic data. | No | Deployment & Post deployment |
| 28 | Azure Local ARB infra | prod5.prod.hot.ingestion.msftcloudes.com | 443 | Periodically sends Microsoft required diagnostic data. | No | Deployment & Post deployment |
| 29 | Azure Local ARB infra | time.windows.com | 123 | OS time sync in appliance VM & Management machine (Windows NTP). | No | Deployment & Post deployment |
| 30 | Azure Local ARB infra | usgovarizona.dp.prod.appliances.azure.us | 443 | Used for ARB data plane operations in US Gov Arizona | No | Deployment & Post deployment |
| 31 | Azure Local Arc agent | *.servicebus.usgovcloudapi.net | 443 | For multiple Azure Local components. | No | Deployment & Post deployment |
| 32 | Azure Local Arc agent | agentserviceapi.guestconfiguration.azure.us | 443 | For notification service for extension and connectivity scenarios. | No | Deployment & Post deployment |
| 33 | Azure Local Arc agent | download.microsoft.com | 443 | For downloading the Windows installation package. | No | Deployment & Post deployment |
| 34 | Azure Local Arc agent | gbl.his.arc.azure.us | 443 | For global metadata and hybrid identity services. | No | Deployment & Post deployment |
| 35 | Azure Local Arc agent | guestnotificationservice.azure.us | 443 | For the notification service for extension and connectivity scenarios. | No | Deployment & Post deployment |
| 36 | Azure Local Arc agent | pasff.usgovcloudapi.net | 443 | For Microsoft Entra ID. | No | Deployment & Post deployment |
| 37 | Azure Local Arc agent | usgv.his.arc.azure.us | 443 | For US Gov Virginia metadata and hybrid identity services. | No | Deployment & Post deployment |
| 38 | Azure Local Arc agent | usgovarizona-gas.guestconfiguration.azure.us | 443 | Used for extension management and guest configuration services in US Gov Arizona. | No | Deployment & Post deployment |
| 39 | Azure Local Arc gateway | yourarcgatewayendpointid.gw.arc.azure.net | 443 | Required if using Arc gateway for Azure Local. ENSURE THIS IS YOUR UNIQUE GATEWAY NAME | No | Deployment & Post deployment |
| 40 | Azure Local authentication | graph.microsoft.us | 443 | For Graph authentication and Azure Resource Bridge RBAC. | No | Deployment & Post deployment |
| 41 | Azure Local authentication | graph.windows.net | 443 | For Graph authentication, token fetch, and validation. | No | Deployment & Post deployment |
| 42 | Azure Local authentication | login.microsoft.com | 443 | Required to fetch and update Azure Resource Manager tokens. | No | Deployment & Post deployment |
| 43 | Azure Local authentication | login.microsoftonline.us | 443 | For Microsoft Entra authority and authentication, including ARM token fetch, update, and validation. | No | Deployment & Post deployment |
| 44 | Azure Local authentication | login.windows.net | 443 | For Microsoft Entra ID. | No | Deployment & Post deployment |
| 45 | Azure Local authentication | usgovarizona.login.microsoftonline.us | 443 | Required to fetch and update Azure Resource Manager tokens for logging into Azure. | No | Deployment & Post deployment |
| 46 | Azure Local authentication | yourhcikeyvaultname.vault.usgovcloudapi.net | 443 | Key vault for deployment secrets. ENSURE THIS IS YOUR UNIQUE KEY VAULT NAME | No | Deployment & Post deployment |
| 47 | Azure Local benefits | crl3.digicert.com | 80 | Platform attestation service on Azure Local to perform a certificate revocation list. | No | Deployment & Post deployment |
| 48 | Azure Local benefits | crl4.digicert.com | 80 | Platform attestation service on Azure Local to perform a certificate revocation list. | No | Deployment & Post deployment |
| 49 | Azure Local CRLs | crl.microsoft.com/pkiinfra | 80 | Azure Local certificate revocation list for mandatory Arc extensions. | No | Deployment & Post deployment |
| 50 | Azure Local CRLs | ocsp.digicert.com | 80 | Required for Public authorities’ certificate revocation list. | No | Deployment & Post deployment |
| 51 | Azure Local CRLs | ocsp.globalsign.com | 80 | Required for Public authorities’ certificate revocation list. | No | Deployment & Post deployment |
| 52 | Azure Local CRLs | ocsp2.globalsign.com | 80 | Required for Public authorities’ certificate revocation list. | No | Deployment & Post deployment |
| 53 | Azure Local CRLs | oneocsp.microsoft.com | 80 | Required for Public authorities’ certificate revocation list. | No | Deployment & Post deployment |
| 54 | Azure Local CRLs | s.symcd.com | 80 | Required for Public authorities’ certificate revocation list. | No | Deployment & Post deployment |
| 55 | Azure Local CRLs | ts-crl.ws.symantec.com | 80 | Required for Public authorities’ certificate revocation list. | No | Deployment & Post deployment |
| 56 | Azure Local CRLs | ts-ocsp.ws.symantec.com | 80 | Required for Public authorities’ certificate revocation list. | No | Deployment & Post deployment |
| 57 | Azure Local deployment | aka.ms | 443 | For resolving addresses to discover Azure Local | No | Deployment & Post deployment |
| 58 | Azure Local deployment | azurestackreleases.download.prss.microsoft.com | 443 | For Azure Local Arc extensions deployment. | No | Deployment & Post deployment |
| 59 | Azure Local deployment | go.microsoft.com | 443 | For Microsoft Update, allowing the OS to receive updates. | No | Deployment & Post deployment |
| 60 | Azure Local deployment | portal.azure.us | 443 | For Azure Local deployment in Azure Government. | No | Deployment & Post deployment |
| 61 | Azure Local deployment | settings-win.data.microsoft.com | 443 | For Azure Local deployment | No | Deployment & Post deployment |
| 62 | Azure Local deployment | www.microsoft.com | 443 | Used to access required Microsoft deployment and update content. | No | Deployment & Post deployment |
| 63 | Azure Local deployment | www.msftconnecttest.com/connecttest.txt | 80 | Bootstrap Windows outbound connectivity validation | No | Deployment |
| 64 | Azure Local deployment | www.powershellgallery.com | 443 | To install required PSGallery modules for Arc registration. | No | Deployment & Post deployment |
| 65 | Azure Local deployment | yourwitnessstorageaccount.blob.core.usgovcloudapi.net | 443 | For multiple Azure Local components. | No | Deployment & Post deployment |
| 66 | Azure Local diag & billing | azurestackhci.azurefd.net | 443 | Previous URL for Data plane for backwards compatibility. | No | Deployment & Post deployment |
| 67 | Azure Local diag & billing | billing.platform.edge.azure.us | 443 | For Data plane licensing billing data. Required only for Azure Local. | No | Deployment & Post deployment |
| 68 | Azure Local diag & billing | dp.azurestackhci.azure.us | 443 | For Data plane diagnostics and billing data. | No | Deployment & Post deployment |
| 69 | Azure Local diag & billing | licensing.platform.edge.azure.us | 443 | For Data plane licensing billing data. Required only for Azure Local. | No | Deployment & Post deployment |
| 70 | Azure Local management | arm-fdweb.usdodeast.cloudapp.usgovcloudapi.net | 443 | Used for Azure Resource Manager operations. | No | Deployment & Post deployment |
| 71 | Azure Local management | management.usgovcloudapi.net | 443 | Initial Azure Local cluster registration, bootstrapping and management operations. | No | Deployment & Post deployment |
| 72 | Azure Local monitoring | adhs.events.data.microsoft.com | 443 | Used for metrics and monitoring telemetry traffic. | No | Deployment & Post deployment |
| 73 | Azure Local monitoring | analysisservice.watson.azure.us | 443 | Used for diagnostics and analysis services. | No | Deployment & Post deployment |
| 74 | Azure Local monitoring | dc.services.visualstudio.com | 443 | Used for metrics and monitoring telemetry traffic. | No | Deployment & Post deployment |
| 75 | Azure Local monitoring | fp1phx.prod.microsoftmetrics.us | 443 | Used for metrics and monitoring telemetry traffic. | No | Deployment & Post deployment |
| 76 | Azure Local monitoring | gcs.monitoring.core.usgovcloudapi.net | 443 | Used for metrics and monitoring telemetry traffic. | No | Deployment & Post deployment |
| 77 | Azure Local monitoring | global.handler.control.monitor.azure.us | 443 | Used for metrics and monitoring telemetry traffic. | No | Deployment & Post deployment |
| 78 | Azure Local monitoring | global.prod.microsoftmetrics.com | 443 | Used for metrics and monitoring telemetry traffic. | No | Deployment & Post deployment |
| 79 | Azure Local monitoring | prod5.prod.microsoftmetrics.com | 443 | Used for metrics and monitoring telemetry traffic. | No | Deployment & Post deployment |
| 80 | Azure Local monitoring | qos.prod.warm.ingest.monitor.core.usgovcloudapi.net | 443 | Used for metrics and monitoring telemetry traffic. | No | Deployment & Post deployment |
| 81 | Azure Local monitoring | usgovarizona-mdm.prod.hot.ingest.monitor.core.usgovcloudapi.net | 443 | Used for metrics and monitoring telemetry traffic. | No | Deployment & Post deployment |
| 82 | Azure Local monitoring | usgovarizona-shared.prod.warm.ingest.monitor.core.usgovcloudapi.net | 443 | Used for metrics and monitoring telemetry traffic. | No | Deployment |
| 83 | Azure Local monitoring | v20.events.data.microsoft.com | 443 | Used for metrics and monitoring telemetry traffic. | No | Deployment & Post deployment |
| 84 | Azure Local WAC | *.waconazure.com | 443 | For Windows Admin Center management after deployment. | No | Post deployment |
| 85 | Microsoft Defender | *.endpoint.security.microsoft.com | 443 | Required only if using Microsoft Defender extension (MDE.windows). | No | Deployment & Post deployment |
| 86 | Microsoft Update | fe2cr.update.microsoft.com | 443 | Used to download Microsoft Update content. | No | Deployment & Post deployment |
| 87 | Microsoft Update | slscr.update.microsoft.com | 443 | Used to download Microsoft Update content. | No | Deployment & Post deployment |
| 88 | Microsoft Update | tsfe.trafficshaping.dsp.mp.microsoft.com | 443 | For Microsoft Update content regulation | No | Deployment & Post deployment |
| 89 | Azure Local CRLs | ctldl.windowsupdate.com | 80 | Windows certificate trust and untrusted-certificate list updates. | No | Deployment & Post deployment |
| 90 | Azure Local Arc agent | agentserviceapi.guestconfiguration.azure.com | 443 | Public-cloud guest-configuration API; included alongside the Government API. | No | Deployment & Post deployment |
| 91 | Azure Local diag & billing | billing.platform.edge.azure.com | 443 | Requested public-cloud billing endpoint; consuming scenario to confirm. | No | Deployment & Post deployment |
| 92 | Azure Local deployment | cdn.oneget.org | 443 | Package discovery and download dependency for PowerShell tooling. | No | Deployment & Post deployment |
| 93 | Azure Local diag & billing | dp.stackhci.azure.com | 443 | Requested public-cloud Azure Local data-plane endpoint; consuming scenario to confirm. | No | Deployment & Post deployment |
| 94 | Azure Local Arc agent | gbl.his.arc.azure.com | 443 | Public-cloud global hybrid-identity discovery service. | No | Deployment & Post deployment |
| 95 | Azure Local monitoring | gcs.prod.monitoring.core.windows.net | 443 | Public-cloud diagnostic and monitoring service. | No | Deployment & Post deployment |
| 96 | Azure Local authentication | graph.microsoft.com | 443 | Public-cloud Microsoft Graph endpoint used by role-based access scenarios. | No | Deployment & Post deployment |
| 97 | Azure Local Arc agent | guestnotificationservice.azure.com | 443 | Public-cloud notification service for extension and connectivity scenarios. | No | Deployment & Post deployment |
| 98 | Azure Local diag & billing | licensing.platform.edge.azure.com | 443 | Requested public-cloud licensing endpoint; consuming scenario to confirm. | No | Deployment & Post deployment |
| 99 | Azure Local authentication | login.microsoftonline.com | 443 | Public-cloud identity-token endpoint; retained in addition to Government identity endpoints. | No | Deployment & Post deployment |
| 100 | Microsoft Defender | winatp-gw-usgv.microsoft.com | 443 | Defender for Endpoint Government command/control service; applies when the relevant Defender scenario is enabled. | No | Deployment & Post deployment |

[virginia]: https://github.com/Azure/AzureStack-Tools/blob/master/HCI/usgovvirginia-hci-endpoints/usgovvirginia-hci-endpoints.md

<!--
Source table adapted from Azure/AzureStack-Tools under the following license.

The MIT License (MIT)

Copyright (c) 2016 Microsoft

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
-->
