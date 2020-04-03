
#VCenter we want to deploy to
$VC = "vctr00pi02lv.corp.nm.org"
#Template we will use to clone
$template = "test-template"
#Datastore buffer to keep datastore below 80% used after deploying new VM.
$DSBuffer = "2048"
#Import VM info from the excel csv file.
$vminfo = import-csv 'C:\Users\nm184804\Desktop\scripts\Provision VM\VNA-Build_12112018.csv'

write-host "Reading in values from Excel sheet. Please wait...."
# connect to VSphere. Will prompt for username and password
Connect-VIServer -Server $VC -WarningAction Continue


foreach ( $vm in $vminfo )
{

#Get all datastores in cluster.
$Datastore = Get-Cluster -Name $vm.Cluster | Get-Datastore | Sort-Object -Property FreespaceGB -Descending:$true | Select-Object -First 1

#Calculate total space needed for VM.
$totalhdspace = [int]$vm.HardDisk1 + [int]$vm.HardDisk2 + [int]$vm.HardDisk3

## if the freespace plus a bit of buffer space is greater than the size needed for the new VM
if (($Datastore.FreespaceGB + $DSBuffer ) -gt $totalhdspace ) {
    
    


    write-host "Datastore $Datastore has enough free space. Depoying VM. Please wait..."

    #create vm, place in required folder, deploy to datastore selected.
    New-VM -Name $vm.Name -Template $template -ResourcePool $vm.Cluster -Datastore $Datastore

    #set cpu count, memory size, and populate note field on VM.
    Set-VM -VM $vm.Name -NumCpu $vm.CPUCores -MemoryGB $vm.Memory -Description $vm.Notes -Confirm:$false

    #create hard drives to requested size.
    if ($vm.HardDisk1 -gt 0) { New-HardDisk -vm $vm.Name -DiskType flat -CapacityGB $vm.HardDisk1 -StorageFormat EagerZeroedThick -Confirm:$false }
    if ($vm.HardDisk2 -gt 0) { New-HardDisk -vm $vm.Name -DiskType flat -CapacityGB $vm.HardDisk2 -StorageFormat EagerZeroedThick -Confirm:$false }
   if ($vm.HardDisk3 -gt 0) { New-HardDisk -vm $vm.Name -DiskType flat -CapacityGB $vm.HardDisk3 -StorageFormat EagerZeroedThick -Confirm:$false }

    #set core per a cpu to optimal settings.
    if ($vmcpu -gt "1")
    {
    $vmcpu1 = $vm.CPUCores/2

    ## create the VirtualMachineConfigSpec with which to reconfig the VM
    $spec = New-Object -Type VMware.Vim.VirtualMachineConfigSpec -Property @{"NumCoresPerSocket" = $vmcpu1}
    ## get the VM, and, using the ExtensionData to access the API, reconfig the VM
    (Get-VM $vm.VMName).ExtensionData.ReconfigVM_Task($spec)
    }

    #Start the VM
    Start-VM -RunAsync -VM $vm.Name

}
else {"oh, no -- not enough freespace on datastore '$($Datastore.Name)' to provision new VM. Please provision new or expand existing datastores"; exit}

}