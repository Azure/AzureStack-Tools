{
    "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
        "name": {
            "value": "<your_vm_name>"
        },
        "location": {
            "value": "<azure_region>"
        },
        "customLocationId": {
            "value": "<your_custom_location_id>"
        },
        "adminUsername": {
            "value": "<admin_username>"
        },
        "adminPassword": {
            "value": "<admin_password>"
        },
        "securityType": {
            "value": "<security_type>"
        },
        "vNicName": {
            "value": "<vNic_name>"
        },
        "privateIPAddress": {
            "value": "<private_ip_address>"
        },
        "subnetId": {
            "value": "<subnet_id>"
        },
        "vmSize": {
            "value": "<vm_size>"
        },
        "enableVirtualDisk": {
            "value": true or false
        },
        "diskName": {
            "value": "<disk_name>"
        },
        "diskSize": {
            "value": <disk_size_integer>
        },
        "processors": {
            "value": <number_of_processors>
        },
        "memoryMB": {
            "value": <memory_in_mb>
        },
        "imageReferenceId": {
            "value": "<image_reference_id>"
        },
        "enableDomainJoin": {
            "value": true or false
        },
        "domainToJoin": {
            "value": "<domain_to_join>"
        },
        "orgUnitPath": {
            "value": "<organizational_unit_path>"
        },
        "domainUsername": {
            "value": "<domain_username>"
        },
        "domainPassword": {
            "value": "<domain_password>"
        }
    }
}
