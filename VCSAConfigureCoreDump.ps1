[CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$VCIP
    )


##############################################################
# Script Description and Disclaimer
# Written By: Jeremy Dixon
# DATE: 1/9/2020 Version .5
#
#Script is provided as is. I'm not responsible for any issues.
#
#Script will connect to vcenter API and configure the core dump service to automatic (Run on startup) and start the service if isn't already running.
###############################################################

################################################
# Configure the variables below for the vCenter
###############################################
$Credentials = GET-CREDENTIAL –Credential (Get-Credential)
$RESTAPIUser = $Credentials.UserName
$RESTAPIPassword = $Credentials.GetNetworkCredential().Password
#$VCIP = "10.237.110.54" #USED FOR TESTING

#################################################################################
# Nothing to configure below this line - Starting the main function of the script
#################################################################################
################################################
# Building vCenter API string & invoking REST API.
################################################
$BaseAuthURL = "https://" + $VCIP + "/rest/com/vmware/cis/"
$BaseURL = "https://" + $VCIP + "/rest/appliance/vmon/service/"
$vCenterSessionURL = $BaseAuthURL + "session"
$Header = @{"Authorization" = "Basic "+[System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($RESTAPIUser+":"+$RESTAPIPassword))}
$Type = "application/json"

Try 
{
$vCenterSessionResponse = Invoke-RestMethod -Uri $vCenterSessionURL -Headers $Header -Method POST -ContentType $Type -SkipCertificateCheck
}
Catch 
{
$_.Exception.ToString()
$error[0] | Format-List -Force
}
# Extracting the session ID from the response
$vCenterSessionHeader = @{'vmware-api-session-id' = $vCenterSessionResponse.value}

########################################################
# Getting netdumper(Core Dump Collector) Service Status.
########################################################
$VCSAServicesURL = $BaseURL+"netdumper"
Try 
{
$NetDumperService = Invoke-RestMethod -Method Get -Uri $VCSAServicesURL -TimeoutSec 100 -Headers $vCenterSessionHeader -ContentType $Type -SkipCertificateCheck

}
Catch 
{
$_.Exception.ToString()
$error[0] | Format-List -Force
}

#Check if service is started.
if($NetDumperService.value.state -ne "STARTED"){
    
    write-host "Core Dump Collection service isn't running. Starting service via API."
    #Start the service

    $VCSAServicesURL = $BaseURL+"netdumper/start"
    Try 
    {
        $return = Invoke-RestMethod -Method POST -Uri $VCSAServicesURL -TimeoutSec 100 -Headers $vCenterSessionHeader -ContentType $Type -SkipCertificateCheck

    }
    Catch 
    {
        $_.Exception.ToString()
        $error[0] | Format-List -Force
    }

}
else { write-host "Core Dump Collection service is already running. No action taken."}

#Check service startup mode. Should be AUTOMATIC.
if($NetDumperService.value.startup_type -ne "AUTOMATIC"){
    
    write-host "Core Dump Collection startup is set to " $NetDumperService.value.startup_type ". Updating startup to AUTOMATIC via API."
    #Build URL to start service
    $VCSAServicesURL = $BaseURL+"netdumper"
    #Build Body for POST API call.
    $startup = @'
{
    "spec": {
        "startup_type": "AUTOMATIC"
    }
}
'@

#Set service startup to AUTOMATIC.
    Try 
    {
        $return = Invoke-RestMethod -Method PATCH -Uri $VCSAServicesURL -TimeoutSec 100 -Headers $vCenterSessionHeader -ContentType $Type -Body $startup -SkipCertificateCheck

    }
    Catch 
    {
        $_.Exception.ToString()
        $error[0] | Format-List -Force
    }

}
else { write-host "Core Dump Collection Startup is already set to " $NetDumperService.value.startup_type  " No action taken."}

###############################################
# End of script
###############################################