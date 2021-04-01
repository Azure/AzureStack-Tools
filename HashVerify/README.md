# Verify File Hash

To use the `Test-FileHash` cmdlet to verify file hash, relative to the `.\HashVerify` folder in the AzureStack-Tools repo, run:

```powershell
Import-Module .\Test-FileHash.psm1 -Force -Verbose
```

Once you import the `Test-FileHash` module, verify the hash of a file by running: 

```powershell
Test-FileHash
```
And input the `ExpectedHash` and `FilePath` as instructed. 

Alternatively, you could provide the parameters in one line:
```powershell
Test-FileHash -ExpectedHash "<expectedHash of the file>" -FilePath "<path to the file>"
```