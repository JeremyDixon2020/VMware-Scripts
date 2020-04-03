# Start Load VMware  Snapin (if not already loaded)
if (!(Get-PSSnapin -Name VMware.VimAutomation.Core -ErrorAction SilentlyContinue)) {
    if (!(Add-PSSnapin -PassThru VMware.VimAutomation.Core)) {
        # Error out if loading fails
        Write-Error "ERROR: Cannot load the VMware Snapin. Is the PowerCLI installed?"
        Exit
    }
}
# End Load VMware  Snapin (if not already loaded)
 
# Start Set Session Timout
$initialTimeout = (Get-PowerCLIConfiguration -Scope Session).WebOperationTimeoutSeconds
Set-PowerCLIConfiguration -Scope Session -WebOperationTimeoutSeconds -1 -Confirm:$False
# End Set Session Timout
 
# Global Paramenters
$VIServer = "vctr00pi02lv.corp.nm.org"
$Verberose = $true
 
 
#Connect to VCenter
$OpenConnection = $global:DefaultVIServers | where { $_.Name -eq $VIServer }
if($OpenConnection.IsConnected) {
    Write-Output "vCenter is Already Connected..."
    $VIConnection = $OpenConnection
} else {
Connect-VIServer -Server $VIServer
 
}
 
foreach ($ds in (Get-Datastore -Name T1-EDW-XIO-01-DS* | where{$_.Type -eq 'VMFS'}))
  
{ 
  
$esx = Get-VMHost -Location ClusterName -Datastore $ds | Get-Random -Count 1
  
$esxcli = Get-EsxCli -VMHost $esx
Write-Host 'Unmapping' $ds on $esx
$esxcli.storage.vmfs.unmap($null, $ds.Name, $null)
 
Write-Host 'Datastore' $ds.Name ' has been unmapped'
  
}
Write-Host 'Completed all Datastore UN-Mappings'
Write-Host 'Disconnecting from VCENTER' $VIServer
 
Disconnect-VIServer $VIServer -Confirm:$false