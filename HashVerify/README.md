# Verify File Hash

To use the `Verify-Hash` cmdlet to verify file hash, relative to the `.\HashVerify` folder in the AzureStack-Tools repo, run:

```powershell
Import-Module .\Verify-Hash.psm1 -Force -Verbose
```

Once you import the `Verify-Hash` module, verify the hash of a file by running: 

```powershell
Verify-Hash
```
And input the `ExpectedHash` and `FilePath` as instructed. 

Alternatively, you could provide the parameters in one line:
```powershell
Verify-Hash -ExpectedHash "<expectedHash of the file>" -FilePath "<path to the file>"
```