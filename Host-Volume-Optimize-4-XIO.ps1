#written by Jeremy Dixon
#Date:10-17-17


Param(
   [Parameter(Mandatory=$True,Position=1)]
 [string]$vcenter,
  [Parameter(Mandatory=$True,Position=2)]
  [string]$ClusterName
)



Connect-VIServer -Server $vcenter


foreach($esx in (Get-Cluster -Name $clusterName | Get-VMHost))
{
  $esxcli = Get-EsxCli -VMHost $esx
  $devices = $esxcli.storage.core.device.list()
  foreach ($device in $devices)
  {
    if ($device.Model -like “XtremApp”)
    {
      $esxcli.storage.core.device.set($false, $null, $device.Device, $null, $null, $null, $null, $null, $null, $null, $null, ‘256’,$null,$null)
      $esxcli.storage.core.device.list()
    }
  }
}

Get-Cluster -Name $clusterName | Get-VMHost | ForEach {Stop-VMHostService -HostService ($_ | Get-VMHostService | Where {$_.Key -eq “TSM-SSH”}) -Confirm:$FALSE}