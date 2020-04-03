# PowerCLI Script for installing a VIB to a host
# @davidstamen
# http://davidstamen.com

# Define Variables
$Cluster = "Tier1-CTX-Epic"
#$vibpath = "/vmfs/volumes/5984809b-7779d45d-792b-0025b5841a84/drivers/scsi-fnic_1.6.0.37-1OEM.600.0.0.2494585.vib"
$vibpath = "/vmfs/volumes/5984809b-7779d45d-792b-0025b5841a84/drivers/nenic-1.0.16.0-1OEM.650.0.0.4598673.x86_64.vib"
$vcenter = "vctr00pi03lv.corp.nm.org"
$cred = Get-Credential

# Connect to vCenter
Connect-VIServer -Server $vcenter -Credential $cred

# Get each host in specified cluster that meets criteria
Get-VMhost -Location $Cluster | where { $_.PowerState -eq "PoweredOn" -and $_.ConnectionState -eq "Maintenance" } | foreach {

    Write-host "Preparing $($_.Name) for ESXCLI" -ForegroundColor Yellow

    $ESXCLI = Get-EsxCli -VMHost $_ -V2

    # Install VIBs
    Write-host "Installing VIB on $($_.Name)" -ForegroundColor Yellow
		
		# Create Installation Arguments
		$insParm = @{
			viburl = $vibpath
			dryrun = $false
			nosigcheck = $true
			maintenancemode = $false
			force = $false
		}
	
	$action = $ESXCLI.software.vib.install.Invoke($insParm)

    # Verify VIB installed successfully
    if ($action.Message -eq "Operation finished successfully."){Write-host "Action Completed successfully on $($_.Name)" -ForegroundColor Green} else {Write-host $action.Message -ForegroundColor Red}
}