#written by Jeremy Dixon
#Date 3-14-18
#Version 1.0

#connect to VCenter
Connect-VIServer -Server vctr00pi03lv.corp.nm.org

#change the location in below command and also the output file name.
Get-VM -Name * -Location Tier4-VXR |get-spbmEntityConfiguration | Export-CSV .\Tier4-VXR-VM-Storage-Policy_3-14.csv


#Check size of VM before executing below command.
#Get-HardDisk -VM stc00pa01lv | Set-SpbmEntityConfiguration -StoragePolicy $policy