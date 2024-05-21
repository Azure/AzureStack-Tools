import json
import requests
import subprocess
import sys

def get_metadata(arm_endpoint, api_version="2022-09-01"):
    metadata_url_suffix = f"/metadata/endpoints?api-version={api_version}"
    metadata_endpoint = None
    try:
        session = requests.Session()
        metadata_endpoint = arm_endpoint + metadata_url_suffix
        response = session.get(metadata_endpoint)
        if response.status_code == 200:
            return response.json()
        else:
            raise Exception(f"ARM metadata endpoint '{metadata_endpoint}' returned status code {response.status_code}.")
    except Exception as err:
        print(f"Failed to request ARM metadata {metadata_endpoint}.")
        print(f"Please ensure you have network connection to access the endpoint. Error: {str(err)}")

if len(sys.argv) < 2:
    raise Exception(f"""The ARM endpoint URL argument is missing, please pass the ARM endpoint URL.
Usage: python winfield_setup.py <ARM Endpoint URL>""")
elif len(sys.argv) > 2:
    raise Exception(f"""This script accepts only one extra argument, but found {len(sys.argv)} arguments.
Usage: python winfield_setup.py <ARM Endpoint URL>""")
arm_endpoint = sys.argv[1].rstrip('/')
arm_metadata = get_metadata(arm_endpoint)
cloud_config = {
    'endpoints' : {
        'activeDirectory' : arm_metadata['authentication']['loginEndpoint'],
        'activeDirectoryGraphResourceId' : arm_metadata['graph'],
        'activeDirectoryResourceId' : arm_metadata['authentication']['audiences'][0],
        'resourceManager' : arm_metadata['resourceManager'],
        'microsoftGraphResourceId' : arm_metadata['graph']
    },
    'suffixes' : {
        'storageEndpoint' : arm_metadata['suffixes']['storage'],
        'keyvaultDns' : arm_metadata['suffixes']['keyVaultDns'],
        'acrLoginServerEndpoint' : arm_metadata['suffixes']['acrLoginServer']
    }
}
with open("cloudconfig.json", "w") as jsonFile:
    json.dump(cloud_config, jsonFile)
# Check cloud with name "winfield" is already registered.
result = subprocess.check_output(['az', 'cloud', 'list', '--query', "[?name == 'Winfield'].name", '-o', 'tsv']).decode("utf-8")
if result:
    # Temporarily set to another cloud.
    subprocess.run(['az', 'cloud', 'set', '-n', "AzureCloud"])
    # Unregister existing winfield cloud.
    subprocess.run(['az', 'cloud', 'unregister', '-n', "Winfield"])
# Register winfield cloud.
subprocess.run(['az', 'cloud', 'register', '-n', 'Winfield', '--cloud-config', '@cloudconfig.json'])
# Set current cloud to winfield.
subprocess.run(['az', 'cloud', 'set', '-n', 'Winfield'])
