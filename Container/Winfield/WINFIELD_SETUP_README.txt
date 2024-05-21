WINFIELD CERTIFICATE AND ENVIRONMENT SETUP

1. Please set up the Winfield root certificate by creating it's PEM file with a .crt ending.
You may need to reformat the PEM file if it was created in Windows, or simply export the certificate 
from your Windows certificate store and convert it to a PEM file with extension ".crt" using OpenSSL.
If you have Git installed, OpenSSL should exist in "C:\Program Files\Git\usr\bin" on Windows.
openssl x509 -in <public .cer path> -outform PEM -out <public .crt path>

2. Copy the certificate to the docker container:
docker cp <.crt file path> <container ID or name>:/usr/local/share/ca-certificates

3. Enter the Winfield docker container by connecting it to the host's network.
docker run -it --network host <repository container>:<version>

4. Update the system certificate authority store:
update-ca-certificates

5. Test that you can access Winfield endpoint with a cURL:
curl <ARM Endpoint URL>/metadata/endpoints?api-version=2022-09-01

6. Run the script '/root/downloads/winfield_setup.py' to set up the 'Winfield' environment. Make sure
to pass the ARM endpoint URL.
python /root/downloads/winfield_setup.py <ARM Endpoint URL>

7. Copy your cluster's kubeconfig file to '~/.kube/config'.
docker cp <path to kubeconfig file> <container ID or name>:/root/.kube

8. Test that you don't get any network errors when you run:
kubectl version