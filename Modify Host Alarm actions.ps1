#Written by Jeremy Dixon
#Date Modified: 1-21-19 V 1.0

################################################################################
## Script will Disable or Enable host alarm actions on all host in a cluster. ## 
################################################################################

#Vcenter we want to connect to.
$VC = "vctr01pi03lv.corp.nm.org"
#Disable or Enable?
$action = "Disable"


#Connect to VCenter
#Connect-VIServer -Server $VC -ErrorAction Stop

$alarmMgr = Get-View AlarmManager

#Disable or Enable?
$action = "Disable"
#Get all host for cluster
$esxi = get-vmhost -location Tier1-CTX-App01

#For each host in cluster, modify the alarm action.
foreach ($esx in $esxi) {

    if($action -eq "Disable") 
    {
        write-host "disabling alarm actions on $esx"
        # To disable alarm actions 
        $alarmMgr.EnableAlarmActions($esx.Extensiondata.MoRef,$fase)
    }
    Else
    {
        write-host "Enabling alarm actions on $esx"
        # To enable alarm actions 
        $alarmMgr.EnableAlarmActions($esx.Extensiondata.MoRef,$true)

    }

}

#Disconnect from vcenter
#Disconnect-VIServer -Server $VC