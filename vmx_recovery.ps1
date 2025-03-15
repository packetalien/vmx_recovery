# VMRegistration.psm1

function Get-CorrectedVMFilePath {
    <#
    .SYNOPSIS
        Corrects the VMX file path for use with New-VM.

    .DESCRIPTION
        Converts the full VMX file path from Get-ChildItem into the format required by New-VM: "[DatastoreName] relative_path".

    .PARAMETER vmxFileFullName
        The full path of the VMX file (e.g., "vmstores:\esxi.example.local\Datastore1\VM1\VM1.vmx").

    .PARAMETER datastoreBrowserPath
        The DatastoreBrowserPath of the datastore (e.g., "vmstores:\esxi.example.local\Datastore1").

    .PARAMETER datastoreName
        The name of the datastore (e.g., "Datastore1").

    .EXAMPLE
        $correctedPath = Get-CorrectedVMFilePath -vmxFileFullName "vmstores:\esxi.example.local\Datastore1\VM1\VM1.vmx" -datastoreBrowserPath "vmstores:\esxi.example.local\Datastore1" -datastoreName "Datastore1"
        # Returns "[Datastore1] VM1/VM1.vmx"
    #>
    param (
        [string]$vmxFileFullName,
        [string]$datastoreBrowserPath,
        [string]$datastoreName
    )
    # Ensure the datastoreBrowserPath ends with a separator for consistency
    if (-not $datastoreBrowserPath.EndsWith('\') -and -not $datastoreBrowserPath.EndsWith('/')) {
        $datastoreBrowserPath += '\'
    }
    # Extract the relative path and standardize to forward slashes
    $startIndex = $datastoreBrowserPath.Length
    $relativePath = $vmxFileFullName.Substring($startIndex).TrimStart('\', '/')
    $relativePath = $relativePath -replace '\\', '/'
    $correctedPath = "[$datastoreName] $relativePath"
    return $correctedPath
}

function Register-VMsFromDatastore {
    <#
    .SYNOPSIS
        Registers VMs from VMX files in a specified datastore on an ESXi host.

    .DESCRIPTION
        Connects to an ESXi host, searches the specified datastore for VMX files, corrects their paths, and registers the VMs on the specified host.

    .PARAMETER ESXiHost
        The IP address or hostname of the ESXi host (e.g., "esxi.example.local").

    .PARAMETER Credential
        The credentials for the ESXi host. Use Get-Credential to create this object (e.g., for user "root@example.local").

    .PARAMETER DatastoreName
        The name of the datastore to search (e.g., "Datastore1").

    .PARAMETER VMHost
        The host where VMs will be registered. Defaults to ESXiHost if not specified.

    .PARAMETER IgnoreCertificateErrors
        Switch to ignore certificate errors during connection (useful for self-signed certificates).

    .EXAMPLE
        $cred = Get-Credential -UserName "root@example.local" -Message "Enter ESXi credentials"
        Register-VMsFromDatastore -ESXiHost "esxi.example.local" -Credential $cred -DatastoreName "Datastore1" -IgnoreCertificateErrors
        # Registers all VMs found in Datastore1 on esxi.example.local, ignoring certificate errors.

    .NOTES
        Requires VMware.PowerCLI module to be installed and imported prior to use.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$ESXiHost,

        [Parameter(Mandatory = $true)]
        [PSCredential]$Credential,

        [Parameter(Mandatory = $true)]
        [string]$DatastoreName,

        [Parameter(Mandatory = $false)]
        [string]$VMHost = $ESXiHost,

        [Parameter(Mandatory = $false)]
        [switch]$IgnoreCertificateErrors
    )

    # Configure PowerCLI to ignore certificate errors if specified
    if ($IgnoreCertificateErrors) {
        Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false
    }

    # Connect to the ESXi host
    Connect-VIServer -Server $ESXiHost -Credential $Credential

    try {
        # Retrieve the datastore object
        $datastore = Get-Datastore -Name $DatastoreName

        # Search for VMX files in the datastore
        $vmxFiles = Get-ChildItem -Path $datastore.DatastoreBrowserPath -Recurse -Include *.vmx

        if ($vmxFiles.Count -eq 0) {
            Write-Host "No VMX files found in the datastore: $DatastoreName"
        } else {
            foreach ($vmxFile in $vmxFiles) {
                try {
                    $correctedVMFilePath = Get-CorrectedVMFilePath -vmxFileFullName $vmxFile.FullName -datastoreBrowserPath $datastore.DatastoreBrowserPath -datastoreName $datastore.Name
                    Write-Host "Processing VMX file: $correctedVMFilePath"
                    New-VM -VMFilePath $correctedVMFilePath -VMHost $VMHost
                    Write-Host "Successfully registered VM: $correctedVMFilePath"
                } catch {
                    Write-Host "Failed to register VM: $($vmxFile.FullName). Error: $_"
                }
            }
        }
    } finally {
        # Disconnect from the ESXi host
        Disconnect-VIServer -Server $ESXiHost -Confirm:$false
    }
}

# Export only the main function as a cmdlet
Export-ModuleMember -Function Register-VMsFromDatastore