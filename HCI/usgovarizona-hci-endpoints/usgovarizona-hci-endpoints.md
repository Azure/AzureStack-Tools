# Azure Local deployment required endpoints for US Gov Arizona

This page provides a comprehensive overview of the necessary endpoints for deploying Azure Local in the US Gov Arizona region. It outlines the specific URLs, ports, and protocols that must be accessible during the deployment process to ensure successful integration with Azure services. The document serves as a resource for IT professionals and system administrators who are preparing to deploy Azure Local solutions in the US Gov Arizona region.

**This list was last updated on October 13th, 2026** - Review GitHub history and pull requests for detailed information.

| Id | Azure Local Component | Endpoint URL | Port | Notes | Arc gateway support | Required for |
|----|-----------------------|--------------|------|-------|---------------------|--------------|
| 1 | Azure Local AKS infra | mcr.microsoft.com | 443 | Used for official Microsoft artifacts such as container images. | No | Deployment & Post deployment |
| 2 | Azure Local AKS infra | sts.windows.net | 443 | Used for cluster connect and custom location scenarios. | No | Deployment & Post deployment |
| 3 | Azure Local AKS infra | usgovarizona.dp.kubernetesconfiguration.azure.us | 443 | Used for Azure Arc configuration in US Gov Arizona. | No | Deployment & Post deployment |
| 4 | Azure Local AKS infra | westus.data.mcr.microsoft.com | 443 | Used to download Microsoft container registry content. | No | Deployment & Post deployment |
| 5 | Azure Local AKS infra | westus2.data.mcr.microsoft.com | 443 | Used to download Microsoft container registry content. | No | Deployment & Post deployment |
| 6 | Azure Local ARB infra | msk8s.api.cdp.microsoft.com | 443 | Used to download product catalogs, product bits, and OS images. | No | Deployment & Post deployment |
| 7 | Azure Local ARB infra | msk8s.sb.tlu.dl.delivery.mp.microsoft.com | 443 | Used to download Azure Resource Bridge OS images. | No | Deployment & Post deployment |
| 8 | Azure Local ARB infra | packages.microsoft.com | 443 | Used to download Linux installation packages. | No | Deployment & Post deployment |
| 9 | Azure Local ARB infra | usgovarizona.dp.prod.appliances.azure.us | 443 | Used for Azure Resource Bridge data plane operations in US Gov Arizona. | No | Deployment & Post deployment |
| 10 | Azure Local Arc agent | agentserviceapi.guestconfiguration.azure.us | 443 | Used for extension notifications and connectivity scenarios. | No | Deployment & Post deployment |
| 11 | Azure Local Arc agent | azgns-usgovarizona-fairfax-1p-public.servicebus.usgovcloudapi.net | 443 | Used for Azure service notifications in US Gov Arizona. | No | Deployment & Post deployment |
| 12 | Azure Local Arc agent | gbl.his.arc.azure.us | 443 | Used for global metadata and hybrid identity services. | No | Deployment & Post deployment |
| 13 | Azure Local Arc agent | guestnotificationservice.azure.us | 443 | Used for extension notifications and connectivity scenarios. | No | Deployment & Post deployment |
| 14 | Azure Local Arc agent | gv12-ffprod-phx20-001-sb.servicebus.usgovcloudapi.net | 443 | Used for Azure Arc service messaging in US Gov Arizona. | No | Deployment & Post deployment |
| 15 | Azure Local Arc agent | gv13-ffprod-phx20-001-sb.servicebus.usgovcloudapi.net | 443 | Used for Azure Arc service messaging in US Gov Arizona. | No | Deployment & Post deployment |
| 16 | Azure Local Arc agent | gv18-ffprod-phx20-001-sb.servicebus.usgovcloudapi.net | 443 | Used for Azure Arc service messaging in US Gov Arizona. | No | Deployment & Post deployment |
| 17 | Azure Local Arc agent | gv19-ffprod-phx20-001-sb.servicebus.usgovcloudapi.net | 443 | Used for Azure Arc service messaging in US Gov Arizona. | No | Deployment & Post deployment |
| 18 | Azure Local Arc agent | gv20-ffprod-phx20-001-sb.servicebus.usgovcloudapi.net | 443 | Used for Azure Arc service messaging in US Gov Arizona. | No | Deployment & Post deployment |
| 19 | Azure Local Arc agent | gv21-ffprod-phx20-001-sb.servicebus.usgovcloudapi.net | 443 | Used for Azure Arc service messaging in US Gov Arizona. | No | Deployment & Post deployment |
| 20 | Azure Local Arc agent | gv24-ffprod-phx20-001-sb.servicebus.usgovcloudapi.net | 443 | Used for Azure Arc service messaging in US Gov Arizona. | No | Deployment & Post deployment |
| 21 | Azure Local Arc agent | gv28-ffprod-phx20-001-sb.servicebus.usgovcloudapi.net | 443 | Used for Azure Arc service messaging in US Gov Arizona. | No | Deployment & Post deployment |
| 22 | Azure Local Arc agent | gv5-ffprod-phx20-001-sb.servicebus.usgovcloudapi.net | 443 | Used for Azure Arc service messaging in US Gov Arizona. | No | Deployment & Post deployment |
| 23 | Azure Local Arc agent | gv8-ffprod-phx20-001-sb.servicebus.usgovcloudapi.net | 443 | Used for Azure Arc service messaging in US Gov Arizona. | No | Deployment & Post deployment |
| 24 | Azure Local Arc agent | oaasguestconfigusgas1.blob.core.usgovcloudapi.net | 443 | Used to download guest configuration content. | No | Deployment & Post deployment |
| 25 | Azure Local Arc agent | pasff.usgovcloudapi.net | 443 | Used for Microsoft Entra ID integration. | No | Deployment & Post deployment |
| 26 | Azure Local Arc agent | usga.his.arc.azure.us | 443 | Used for US Gov Arizona metadata and hybrid identity services. | No | Deployment & Post deployment |
| 27 | Azure Local Arc agent | usgovarizona-gas.guestconfiguration.azure.us | 443 | Used for extension management and guest configuration services in US Gov Arizona. | No | Deployment & Post deployment |
| 28 | Azure Local Arc agent | usgovtexas-gas.guestconfiguration.azure.us | 443 | Used for extension management and guest configuration services. | No | Deployment & Post deployment |
| 29 | Azure Local Arc agent | usgv.his.arc.azure.us | 443 | Used for US Government metadata and hybrid identity services. | No | Deployment & Post deployment |
| 30 | Azure Local authentication | graph.microsoft.com | 443 | Used for Microsoft Graph operations. | No | Deployment & Post deployment |
| 31 | Azure Local authentication | graph.microsoft.us | 443 | Used for Microsoft Graph authentication and Azure Resource Bridge RBAC. | No | Deployment & Post deployment |
| 32 | Azure Local authentication | hcikv2610v423.vault.usgovcloudapi.net | 443 | Used to access the Azure Local deployment key vault. | No | Deployment & Post deployment |
| 33 | Azure Local authentication | login.microsoftonline.com | 443 | Used for Microsoft Entra authentication. | No | Deployment & Post deployment |
| 34 | Azure Local authentication | login.microsoftonline.us | 443 | Used for Microsoft Entra authentication in Azure Government. | No | Deployment & Post deployment |
| 35 | Azure Local authentication | usgovarizona.login.microsoftonline.us | 443 | Used to fetch and update Azure Resource Manager tokens. | No | Deployment & Post deployment |
| 36 | Azure Local CRLs | ocsp.digicert.com | 80 | Used to check public certificate revocation status. | No | Deployment & Post deployment |
| 37 | Azure Local CRLs | oneocsp.microsoft.com | 80 | Used to check public certificate revocation status. | No | Deployment & Post deployment |
| 38 | Azure Local deployment | aka.ms | 443 | Used to resolve addresses required by Azure Local. | No | Deployment & Post deployment |
| 39 | Azure Local deployment | azcliprod.blob.core.windows.net | 443 | Used to download Azure CLI content. | No | Deployment & Post deployment |
| 40 | Azure Local deployment | azurestackreleases.download.prss.microsoft.com | 443 | Used for Azure Local Arc extension deployment. | No | Deployment & Post deployment |
| 41 | Azure Local deployment | cdn.oneget.org | 443 | Used to download package management content. | No | Deployment & Post deployment |
| 42 | Azure Local deployment | go.microsoft.com | 443 | Used for Microsoft Update and Azure Local deployment content. | No | Deployment & Post deployment |
| 43 | Azure Local deployment | hciwt2610v423.blob.core.usgovcloudapi.net | 443 | Used to access Azure Local deployment storage. | No | Deployment & Post deployment |
| 44 | Azure Local deployment | settings-win.data.microsoft.com | 443 | Used for Azure Local deployment. | No | Deployment & Post deployment |
| 45 | Azure Local deployment | umsa40gxfvs5hmwqhktm.blob.core.usgovcloudapi.net | 443 | Used to access Azure Local deployment content. | No | Deployment & Post deployment |
| 46 | Azure Local deployment | umsaht5nqkpfpp1rdgrx.blob.core.usgovcloudapi.net | 443 | Used to access Azure Local deployment content. | No | Deployment & Post deployment |
| 47 | Azure Local deployment | umsar0xbrbdkssjqb545.blob.core.usgovcloudapi.net | 443 | Used to access Azure Local deployment content. | No | Deployment & Post deployment |
| 48 | Azure Local deployment | umsaw51vvbjnmqbhc2rn.blob.core.usgovcloudapi.net | 443 | Used to access Azure Local deployment content. | No | Deployment & Post deployment |
| 49 | Azure Local deployment | www.microsoft.com | 80 | Used to access required Microsoft deployment and update content. | No | Deployment & Post deployment |
| 50 | Azure Local deployment | www.powershellgallery.com | 443 | Used to install required PowerShell Gallery modules for Arc registration. | No | Deployment & Post deployment |
| 51 | Azure Local diag & billing | dp.azurestackhci.azure.us | 443 | Used for data plane diagnostics and billing data. | No | Deployment & Post deployment |
| 52 | Azure Local diag & billing | licensing.platform.edge.azure.us | 443 | Used for Azure Local licensing and billing data. | No | Deployment & Post deployment |
| 53 | Azure Local management | management.azure.com | 443 | Used for Azure Resource Manager operations. | No | Deployment & Post deployment |
| 54 | Azure Local management | management.usgovcloudapi.net | 443 | Used for Azure Local registration, bootstrapping, and management operations. | No | Deployment & Post deployment |
| 55 | Azure Local monitoring | analysisservice.watson.azure.us | 443 | Used for diagnostics and analysis services. | No | Deployment & Post deployment |
| 56 | Azure Local monitoring | aw0ap0usgsw10dmp.blob.core.usgovcloudapi.net | 443 | Used for Azure Local diagnostic and monitoring data. | No | Deployment & Post deployment |
| 57 | Azure Local monitoring | azureprofiler.trafficmanager.net | 443 | Used for Azure profiling and diagnostics traffic. | No | Deployment & Post deployment |
| 58 | Azure Local monitoring | dc.services.visualstudio.com | 443 | Used for metrics and monitoring telemetry traffic. | No | Deployment & Post deployment |
| 59 | Azure Local monitoring | ffglobal.prod.microsoftmetrics.us | 443 | Used for metrics and monitoring telemetry traffic. | No | Deployment & Post deployment |
| 60 | Azure Local monitoring | fp1phx.prod.microsoftmetrics.us | 443 | Used for metrics and monitoring telemetry traffic. | No | Deployment & Post deployment |
| 61 | Azure Local monitoring | gcs.monitoring.core.usgovcloudapi.net | 443 | Used for metrics and monitoring telemetry traffic. | No | Deployment & Post deployment |
| 62 | Azure Local monitoring | global.prod.microsoftmetrics.com | 443 | Used for metrics and monitoring telemetry traffic. | No | Deployment & Post deployment |
| 63 | Azure Local monitoring | mobile.events.data.microsoft.com | 443 | Used for metrics and monitoring telemetry traffic. | No | Deployment & Post deployment |
| 64 | Azure Local monitoring | prod5.prod.microsoftmetrics.com | 443 | Used for metrics and monitoring telemetry traffic. | No | Deployment & Post deployment |
| 65 | Azure Local monitoring | tb.events.data.microsoft.com | 443 | Used for metrics and monitoring telemetry traffic. | No | Deployment & Post deployment |
| 66 | Azure Local monitoring | us4-v20.events.data.microsoft.com | 443 | Used for metrics and monitoring telemetry traffic. | No | Deployment & Post deployment |
| 67 | Azure Local monitoring | usgovarizona-mdm.prod.hot.ingest.monitor.core.usgovcloudapi.net | 443 | Used for metrics and monitoring telemetry traffic. | No | Deployment & Post deployment |
| 68 | Azure Local monitoring | usgovarizona-qos.prod.warm.ingest.monitor.core.usgovcloudapi.net | 443 | Used for metrics and monitoring telemetry traffic. | No | Deployment & Post deployment |
| 69 | Azure Local monitoring | usgovarizona-shared.prod.warm.ingest.monitor.core.usgovcloudapi.net | 443 | Used for metrics and monitoring telemetry traffic. | No | Deployment & Post deployment |
| 70 | Azure Local monitoring | us-v10.events.data.microsoft.com | 443 | Used for metrics and monitoring telemetry traffic. | No | Deployment & Post deployment |
| 71 | Azure Local monitoring | us-v20.events.data.microsoft.com | 443 | Used for metrics and monitoring telemetry traffic. | No | Deployment & Post deployment |
| 72 | Azure Local monitoring | v20.events.data.microsoft.com | 443 | Used for metrics and monitoring telemetry traffic. | No | Deployment & Post deployment |
| 73 | Microsoft 365 | ecs.office.com | 443 | Used to retrieve Microsoft service configuration. | No | Deployment & Post deployment |
| 74 | Microsoft Defender | definitionupdates.microsoft.com | 443 | Used to download Microsoft Defender definition updates. | No | Deployment & Post deployment |
| 75 | Microsoft Defender | nf.smartscreen.microsoft.com | 443 | Used by Microsoft Defender SmartScreen. | No | Deployment & Post deployment |
| 76 | Microsoft Defender | reflector.defender.microsoft.com | 443 | Used for Microsoft Defender security intelligence updates. | No | Deployment & Post deployment |
| 77 | Microsoft Defender | unitedstates1.cp.wd.microsoft.us | 443 | Used for Microsoft Defender cloud protection. | No | Deployment & Post deployment |
| 78 | Microsoft Defender | wdcp.microsoft.com | 443 | Used for Microsoft Defender cloud protection. | No | Deployment & Post deployment |
| 79 | Microsoft Defender | wdcpalt.microsoft.com | 443 | Used for Microsoft Defender cloud protection. | No | Deployment & Post deployment |
| 80 | Microsoft Defender | winatp-gw-usgv.microsoft.com | 443 | Used for Microsoft Defender for Endpoint in Azure Government. | No | Deployment & Post deployment |
| 81 | Microsoft Update | 3.au.download.windowsupdate.com | 80 | Used to download Microsoft Update content. | No | Deployment & Post deployment |
| 82 | Microsoft Update | 4.au.download.windowsupdate.com | 80 | Used to download Microsoft Update content. | No | Deployment & Post deployment |
| 83 | Microsoft Update | au.download.windowsupdate.com | 80 | Used to download Microsoft Update content. | No | Deployment & Post deployment |
| 84 | Microsoft Update | cp601.prod.do.dsp.mp.microsoft.com | 443 | Used to download Microsoft Update content. | No | Deployment & Post deployment |
| 85 | Microsoft Update | ctldl.windowsupdate.com | 80 | Used to download Microsoft Update content. | No | Deployment & Post deployment |
| 86 | Microsoft Update | download.windowsupdate.com | 80 | Used to download Microsoft Update content. | No | Deployment & Post deployment |
| 87 | Microsoft Update | fe2cr.update.microsoft.com | 443 | Used to download Microsoft Update content. | No | Deployment & Post deployment |
| 88 | Microsoft Update | fe3cr.delivery.mp.microsoft.com | 443 | Used to download Microsoft Update content. | No | Deployment & Post deployment |
| 89 | Microsoft Update | geo.prod.do.dsp.mp.microsoft.com | 443 | Used to locate Microsoft Update content. | No | Deployment & Post deployment |
| 90 | Microsoft Update | geover.prod.do.dsp.mp.microsoft.com | 443 | Used to locate Microsoft Update content. | No | Deployment & Post deployment |
| 91 | Microsoft Update | kv601.prod.do.dsp.mp.microsoft.com | 443 | Used to access Microsoft Update content metadata. | No | Deployment & Post deployment |
| 92 | Microsoft Update | tas02.sls.update.microsoft.com | 443 | Used to discover Microsoft Update services. | No | Deployment & Post deployment |
| 93 | Microsoft Update | tsfe.trafficshaping.dsp.mp.microsoft.com | 443 | Used for Microsoft Update content regulation. | No | Deployment & Post deployment |
