<#
.SYNOPSIS
Vmware functions used to configure VCSA Appliance, ESXi, Vcenter settings.

.DESCRIPTION
Script will perform the following.
Configure ESXi coredump settings.
Configure Vcenter coredump service.
Disable the virtual appliance root password from expiring after 90 days.

.EXAMPLE
Change into directory where script is located. Run it with .\VMware-Utility.ps1
Answer prompts for IP address and login information.

.NOTES
Written By Jeremy Dixon. 
DATE: 2020.3.2

#>

########################################
# Nothing to configure below this line.
########################################

#Check for powershell version 6.
if(($PSVersionTable.PSVersion.Major) -lt "6") {write-host "Incorrect version of powershell installed. Please install Powershell version 6 to use this script."-ForegroundColor Yellow; break } 
#Check for PowerCLI version 11 or above.
$pcli = Get-Module -Name VMware.VimAutomation.Cis.Core | Select-Object -Property Name,Version
#if($pcli.Version.Major -lt "11"){write-host "Incorrect version of PowerCLI installed. Please install PowerCLI version 11 or greater to use this script"-ForegroundColor Yellow; break}


#$vcenterip = "10.237.110.54" #USED FOR TESTING

write-host "Please provide the Vcenter IP"
$vcenterip = Read-Host "VCenter IP Address"

# Run once to create secure credential file
$credfile = ".\SecureCredentials.xml"
If(!(Test-Path -Path $credfile))
{
     GET-CREDENTIAL –Credential (Get-Credential) | EXPORT-CLIXML $credfile 
}
# Run at the start of each script to import the credentials
$Cred = IMPORT-CLIXML $credfile

#Authenticate against Vcenter for PowerCLI commands
Connect-VIServer -Server $vcenterip -Credential $Cred

###################################################
####### Show Menu for different functions.
###################################################
function Show-VMwareMenu {
    param (
        [string]$Title = 'VMware Menu'
    )
    Clear-Host
    Write-Host "================ $Title ================"

  
    Write-Host "1: Press '1' to configure Vcenter coredump service"
    Write-Host "2: Press '2' to get  ESXi coredump settings."
    Write-Host "3: Press '3' to disable Root Password Expiring on virtual appliance management interface (VAMI)"
    Write-Host "Q: Press 'Q' to quit."
}
###################################################
#######Get API Session ID
###################################################
function GetSessionID
{
    $BaseAuthURL = "https://" + $vcenterip + "/rest/com/vmware/cis/"
    $vCenterSessionURL = $BaseAuthURL + "session"
    $Header = @{"Authorization" = "Basic "+[System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($Cred.UserName+':'+$Cred.GetNetworkCredential().Password))}
    $Type = "application/json"

    #Authenticate
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

    return $vCenterSessionHeader
}

###################################################
####### Configure Core Dump Service on VCenter.
###################################################
function Config-VCCoreDumpService {

    $BaseURL = "https://" + $vcenterip + "/rest/appliance/vmon/service/"
    $Type = "application/json"
    
    
    ########################################################
    # Getting netdumper(Core Dump Collector) Service Status.
    ########################################################
    #Build URL
    $VCSAServicesURL = $BaseURL+"netdumper"
    Try 
    {
    $NetDumperService = Invoke-RestMethod -Method Get -Uri $VCSAServicesURL -TimeoutSec 100 -Headers $Session -ContentType $Type -SkipCertificateCheck
    
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
        $return = Invoke-RestMethod -Method POST -Uri $VCSAServicesURL -TimeoutSec 100 -Headers $Session -ContentType $Type -SkipCertificateCheck

    }
    Catch 
    {
        $_.Exception.ToString()
        $error[0] | Format-List -Force
    }

}
else { write-host "Core Dump Collection service already running. No action taken."}

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
        $return = Invoke-RestMethod -Method PATCH -Uri $VCSAServicesURL -TimeoutSec 100 -Headers $Session -ContentType $Type -Body $startup -SkipCertificateCheck

    }
    Catch 
    {
        $_.Exception.ToString()
        $error[0] | Format-List -Force
    }

}
else { write-host "Core Dump Collection Startup is already set to " $NetDumperService.value.startup_type  ". No action taken."}
}

function Config-VAMIRootPWExpire {

    $BaseURL = "https://" + $vcenterip + "/rest/appliance/local-accounts/root"
    $Type = "application/json"
    
    ########################################################
    # Getting netdumper(Core Dump Collector) Service Status.
    ########################################################
    #Build URL

    Try 
    {
    $response = Invoke-RestMethod -Method Get -Uri $BaseURL -TimeoutSec 100 -Headers $Session -ContentType $Type -SkipCertificateCheck
    
    }
    Catch 
    {
    $_.Exception.ToString()
    $error[0] | Format-List -Force
    }
    

    $rootpwexpires = $response.value.password_expires_at
    ## If password varaibles is set/present, disable it.
    If ($rootpwexpires) {

        write-host "Root password is set to expire at:"  $rootpwexpires "." -ForegroundColor Red
        write-host "Setting root password to not expire on VAMI host:" $vcenterip"." -ForegroundColor Yellow
        
        #Post body for Patch API call.
        $body = @'
        {
            "config": {
                "password_expires": false
            }
        }
'@
            #Patch API call to update root password to not expire.
        Try 
         {
            $response = Invoke-RestMethod -Method Patch -Uri $BaseURL -TimeoutSec 100 -Headers $Session -ContentType $Type -Body $Body -SkipCertificateCheck
    
        }
        Catch 
        {
             $_.Exception.ToString()
            $error[0] | Format-List -Force
        }

        #Validate the root password is set to not expire. Above API Patch call doesn't have output.
        Try 
        {
        $response = Invoke-RestMethod -Method Get -Uri $BaseURL -TimeoutSec 100 -Headers $Session -ContentType $Type -SkipCertificateCheck
        
        }
        Catch 
        {
        $_.Exception.ToString()
        $error[0] | Format-List -Force
        }
        $rootpwexpires = $response.value.password_expires_at
        If (!$rootpwexpires){ write-host "Root password reconfigured to not expire." -ForegroundColor Green }

    }
    else {
        write-host "Root password on $vcenterIP isn't set to expire. Nothing to do." -ForegroundColor Green
    }
    
}

#Function to get CoreDump Settings for each host.
function Get-ESXiCoreDumpConfig {
    $results = @()

    foreach($vmhost in (Get-VMHost)){
       
        $esxcli = Get-EsxCli -VMHost $vmhost.Name
        write-host "Getting coredump settings for host:" $vmhost.Name
        $results += $esxcli.system.hostname.get()
        $results += $esxcli.system.coredump.network.get()
    }

    #$test = $Results | Where-Object {$Results.NetworkServerIP -ne "10.237.110.5"}
    return $results
}

#Function to set CoreDump Settings for each host.
function Set-ESXiCoreDump {
 
    Param($vcenterip)
    
   foreach($vmhost in (Get-VMHost)){
    $esxcli = Get-EsxCli -VMHost $vmhost.Name
    $esxcli.system.coredump.network.set($null,"vmk0",$null,$vcenterip,6500)
    $esxcli.system.coredump.network.set($true)
    $esxcli.system.coredump.network.get()
    }
}

#Function to test CoreDump Collector on each Host.
function Test-ESXiCoreDump {
    
     Param($vcenterip)

    foreach($vmhost in (Get-VMHost)){
    $esxcli = Get-EsxCli -VMHost $vmhost.Name
    Write-Host "Checking dump collector on host $vmhost.name"
    $esxcli.system.coredump.network.check()
    }

}
########################################################################################################################
############################## END OF FUNCTION SECTION. Starting Main Script ###########################################
########################################################################################################################

#do
 #{
    Show-VMwareMenu -Title "VMware Menu"
    $input = Read-Host "Please make a selection"
Switch ($input) {
"1" {
    Write-Host "Configuring Vcenter core dump collection service." -ForegroundColor Green
    $Session = GetSessionID $vcenterip $Cred
    Config-VCCoreDumpService $vcenterip $Session
}
 
"2" {
    Write-Host " VMware ESXi CoreDump Menu" -ForegroundColor Green
    Get-ESXiCoreDumpConfig
}
 
"3" {
    Write-Host "Disable Root Password Expiring on virtual appliance management interface (VAMI)" -ForegroundColor Green
    $Session = GetSessionID $vcenterip $Cred
    Config-VAMIRootPWExpire $vcenterip $Session
}
 
"Q" {
    Write-Host "Quit" -ForegroundColor Green
    If((Test-Path -Path $credfile))
    {
        #Delete Credential file and Terminate RESTAPI Session
        Remove-Item -Path $credfile -Force
        #Invoke-RestMethod -Method Delete -Uri $TerminateURI -TimeoutSec 100 -Headers $Session -ContentType $Type -SkipCertificateCheck

     
    }
}
 
default {
    Write-Host "I don't understand what you want to do." -ForegroundColor Yellow
 }
} #end switch

#Delete Credential file
Remove-Item -Path $credfile -Force
#}
#while ($input -ne 'Q') #If input equals q then stop the script