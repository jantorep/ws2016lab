# ------------------------------------------------------------------------------
# Create Virtual Machine Script for S2D Cluster with Virtual Machine Manager
# ------------------------------------------------------------------------------
# Update the script with your config to the Install Script starts
# ------------------------------------------------------------------------------
#Preq to have Hyper-V Module installed on vmm server
#Install-WindowsFeature -Name Hyper-V-PowerShell
 

#Default error action is to stop if any problems
$ErrorActionPreference = "stop"
Get-SCVMMServer $env:COMPUTERNAME | Out-Null
#Import VMM module
If (!(Get-Module VirtualMachineManager)) {Import-Module VirtualMachineManager}

#region LAB Config
# 2,3,4,8, or 16 nodes
$numberofnodes = 2
$ServersNamePrefix = "S2D"
#generate servernames (based number of nodes and serversnameprefix)
$Servers = @()
1..$numberofnodes | ForEach-Object {$servers += "$ServersNamePrefix$_"}
#Physical Hyper-V Host Name start with
$HostName = "S2DNode1"
$PhysicalHosts = @()
1..$numberofnodes | ForEach-Object {$PhysicalHosts += "$HostName$_"}
#Set the OS version you are deploying, use Windows Server Datacenter Version 1709 for Insider Builds
$OSVersion = "Windows Server 2016 Datacenter"
#VMM Host Group to deploy to
$HGName = "All Hosts\S2D"
#Domain
$Domain = "contoso.corp"
$DC = "DC01"
#RunasAccountName
$RunasAccountName = "contoso\administrator"
#Cluster Name
$ClusterName = "S2D-Cluster"
$ClusterIPs = "10.0.0.130"
#Networking
$MGMTNet = "10.0.0." #With the Start IP it will start at 10.0.0.111
$MGMTVlan = 10
$MGMTStartIP = 121
$StorNet = "172.0.0." #With the Start IP it will start at 172.0.0.201
$StorVlan = "10-50" #For VM nic's
$StorageVlan = 50
$StorStartIP = 201
$DefaultGW = 10.0.0.138
#StoragePool virtualdisk
$Numberofdisks = 6
$VirtualdiskSize = 81920
$SizeOfVolumes = "40GB"
#CSV drive path and name
#$ClustersharedVolumePath = C:\ClusterStorage\Volume
#Template Name
$Templatename = "WS2019_RS5"
# Enter Logical Networks from VMM
$HostVMNetwork = "Hyper-V Management"
$SMB1VMNetwork = "Hyper-V Storage"
$SMB2VMNetwork = "Hyper-V Storage"
# Enter Logical Switch Info from VMM
$LogicalSwitchName = "S2D Switch" ##Defines the Logical Switch used for VM workloads
$UplinkProfileName = "S2DUpplink"
#Might need to set MGMTsubnet and IP of host if Pnic 2 can't be added to vswitch during deployment.
$MGMTSubnet = "10.0.0.0/24"
$ManagmentnicIPStart = "10.0.0.11" #This will start at 10.0.0.111 as we will add 1 pr server
$DNSServer1 = "10.0.0.16"
$DNSServer2 = "10.0.0.17"
## Get Port classifications
$PortClassificationHost = Get-SCPortClassification -Name "Host Management"
$PortClassificationStorage = Get-SCPortClassification -Name "Storage RDMA"
#Hardware Profile Info
$CPUType = Get-SCCPUType -VMMServer localhost | Where-Object {$_.Name -eq "3.60 GHz Xeon (2 MB L2 cache)"}
$CapabilityProfile = Get-SCCapabilityProfile -VMMServer localhost | Where-Object {$_.Name -eq "Hyper-V"}
#Get VMNetworks
$VMNetworkHost = Get-SCVMNetwork -Name $HostVMNetwork
$VMNetworkSMB1 = Get-SCVMNetwork -Name $SMB1VMNetwork
$VMNetworkSMB2 = Get-SCVMNetwork -Name $SMB2VMNetwork
$HostLogical = Get-SCLogicalNetwork -Name $VMNetworkHost.LogicalNetwork
$SMB1Logical = Get-SCLogicalNetwork -Name $VMNetworkSMB1.LogicalNetwork
$SMB2Logical = Get-SCLogicalNetwork -Name $VMNetworkSMB2.LogicalNetwork
## Getting info
$HostGroup = Get-SCVMHostGroup | Where-Object { $_.Path -eq $HGName }
## Getting Switch Info
$LogicalSwitch = Get-SCLogicalSwitch -Name $LogicalSwitchName
$SwitchUplinkPortProfileSet = Get-SCUplinkPortProfileSet -LogicalSwitch $LogicalSwitch -Name $UplinkProfileName
## Getting Subnet Info
$HostLogicalDef = Get-SCLogicalNetworkDefinition -VMHostGroup $HostGroup -LogicalNetwork $HostLogical
#$HostIPPool = Get-SCStaticIPAddressPool -VMHostGroup $HostGroup | Where-Object {$_.LogicalNetworkDefinition -like $CSVLM1LogicalDef}
$HostSubnet = $HostLogicalDef.SubnetVLans.subnet    
$SMB1LogicalDef = Get-SCLogicalNetworkDefinition -VMHostGroup $HostGroup -LogicalNetwork $SMB1Logical
#$SMB1IPPool = Get-SCStaticIPAddressPool -VMHostGroup $HostGroup | Where-Object {$_.LogicalNetworkDefinition -like $SMB1LogicalDef}
$SMB1Subnet = $SMB1LogicalDef.SubnetVLans.subnet
$SMB2LogicalDef = Get-SCLogicalNetworkDefinition -VMHostGroup $HostGroup -LogicalNetwork $SMB2Logical
#$SMB2IPPool = Get-SCStaticIPAddressPool -VMHostGroup $HostGroup | Where-Object {$_.LogicalNetworkDefinition -like $SMB2LogicalDef}
$SMB2Subnet = $SMB2LogicalDef.SubnetVLans.subnet

#Install S2D VM's with VMM (based number of nodes and serversnameprefix)
foreach ($server in $servers) {
        
    $jobId = New-Guid
    New-SCVirtualScsiAdapter -VMMServer localhost -JobGroup $jobId -AdapterID 7 -ShareVirtualScsiAdapter $false -ScsiControllerType DefaultTypeNoType 
    New-SCVirtualScsiAdapter -VMMServer localhost -JobGroup $jobId -AdapterID 7 -ShareVirtualScsiAdapter $false -ScsiControllerType DefaultTypeNoType
    New-SCVirtualDVDDrive -VMMServer localhost -JobGroup $jobId -Bus 0 -LUN 1 

    #MGMT NIC1
    New-SCVirtualNetworkAdapter -VMMServer localhost -JobGroup $jobId -MACAddress "00:00:00:00:00:00" -MACAddressType Static -VLanEnabled $false -Synthetic -IPv4AddressType Static -IPv6AddressType Dynamic -VMNetwork $VMNetworkHost -PortClassification $PortClassificationHost -DevicePropertiesAdapterNameMode Custom -DevicePropertiesAdapterName "NIC1"
    #MGMT NIC2
    New-SCVirtualNetworkAdapter -VMMServer localhost -JobGroup $jobId -MACAddress "00:00:00:00:00:00" -MACAddressType Static -VLanEnabled $false -Synthetic -IPv4AddressType Static -IPv6AddressType Dynamic -VMNetwork $VMNetworkHost -PortClassification $PortClassificationHost -DevicePropertiesAdapterNameMode Custom -DevicePropertiesAdapterName "NIC2"
    #SMB1 NIC
    #New-SCVirtualNetworkAdapter -VMMServer localhost -JobGroup $jobId -MACAddress "00:00:00:00:00:00" -MACAddressType Static -VLanEnabled $false -Synthetic -IPv4AddressType Static -IPv6AddressType Dynamic -VMNetwork $VMNetworkSMB1 -PortClassification $PortClassificationStorage -DevicePropertiesAdapterNameMode Custom -DevicePropertiesAdapterName "SMB1"        
    #SMB2 NIC
    #New-SCVirtualNetworkAdapter -VMMServer localhost -JobGroup $jobId -MACAddress "00:00:00:00:00:00" -MACAddressType Static -VLanEnabled $false -Synthetic -IPv4AddressType Static -IPv6AddressType Dynamic -VMNetwork $VMNetworkSMB2 -PortClassification $PortClassificationStorage -DevicePropertiesAdapterNameMode Custom -DevicePropertiesAdapterName "SMB2" 
                         
    New-SCHardwareProfile -VMMServer localhost -CPUType $CPUType -Name "Profile$server" -Description "Profile used to create a VM/Template" -CPUCount 4 -MemoryMB 4096 -DynamicMemoryEnabled $false -MemoryWeight 5000 -CPUExpectedUtilizationPercent 20 -DiskIops 0 -CPUMaximumPercent 100 -CPUReserve 0 -NumaIsolationRequired $false -NetworkUtilizationMbps 0 -CPURelativeWeight 100 -HighlyAvailable $true -HAVMPriority 2000 -DRProtectionRequired $false -SecureBootEnabled $true -SecureBootTemplate "MicrosoftWindows" -CPULimitFunctionality $false -CPULimitForMigration $false -CheckpointType Production -CapabilityProfile $CapabilityProfile -Generation 2 -JobGroup $jobId 
                                               
    #Virtualdisks to S2D node
    $S2DPoolDisks = 2..$Numberofdisks | ForEach-Object {
        New-SCVirtualDiskDrive -VMMServer localhost -SCSI -Bus 1 -LUN $_ -JobGroup $jobId -VirtualHardDiskSizeMB $VirtualdiskSize -CreateDiffDisk $false -Dynamic -Filename "$($server)_disk_$($_)" -VolumeType None 
    }
    $S2DPoolDisks | ForEach-Object {WriteInfo "`t Disk SSD $($_.path) size $($_.size /1GB)GB created"}

    #Get HW profile, template and operatting system
    $Template = Get-SCVMTemplate -VMMServer localhost | Where-Object {$_.Name -eq "$Templatename"}
    $HardwareProfile = Get-SCHardwareProfile -VMMServer localhost | Where-Object {$_.Name -eq "Profile$server"}

    $OperatingSystem = Get-SCOperatingSystem -VMMServer localhost | Where-Object {$_.Name -eq "$OSVersion"}

    $DomainJoinCredential = get-scrunasaccount -VMMServer "localhost" -Name "$RunasAccountName"
    New-SCVMTemplate -Name "Temporary Templated $Server" -Template $Template -HardwareProfile $HardwareProfile -JobGroup $jobId -ComputerName $Server -TimeZone 110  -Domain $Domain -DomainJoinCredential $DomainJoinCredential -AnswerFile $null -OperatingSystem $OperatingSystem 
                        
    $template = Get-SCVMTemplate -Name "Temporary Templated $Server"
    $virtualMachineConfiguration = New-SCVMConfiguration -VMTemplate $template -Name "$Server"
    Write-Output $virtualMachineConfiguration
            
    $vmHost = Get-SCVMHost -ComputerName $($server.replace($ServersNamePrefix, $HostName))
    Set-SCVMConfiguration -VMConfiguration $virtualMachineConfiguration -VMHost $vmHost
    Update-SCVMConfiguration -VMConfiguration $virtualMachineConfiguration
    Set-SCVMConfiguration -VMConfiguration $virtualMachineConfiguration -VMLocation "C:\ClusterStorage\$($server.replace($ServersNamePrefix,"Volume"))\" -PinVMLocation $true


    $AllNICConfigurations = Get-SCVirtualNetworkAdapterConfiguration -VMConfiguration $virtualMachineConfiguration
            
    $VHDConfiguration = Get-SCVirtualHardDiskConfiguration -VMConfiguration $virtualMachineConfiguration
    $VHDConfiguration = $VHDConfiguration[0]
    Set-SCVirtualHardDiskConfiguration -VHDConfiguration $VHDConfiguration -PinSourceLocation $false -DestinationLocation "C:\ClusterStorage\$($server.replace($ServersNamePrefix,"Volume"))\" -FileName "$($server)_disk_1.vhdx" -StorageQoSPolicy $null -DeploymentOption "UseNetwork"
    $VHDConfiguration = Get-SCVirtualHardDiskConfiguration -VMConfiguration $virtualMachineConfiguration
    $VHDConfiguration = $VHDConfiguration[1]
    Set-SCVirtualHardDiskConfiguration -VHDConfiguration $VHDConfiguration -PinSourceLocation $false -DestinationLocation "C:\ClusterStorage\$($server.replace($ServersNamePrefix,"Volume"))\" -FileName "$($server)_disk_2" -StorageQoSPolicy $null -DeploymentOption "None"
    $VHDConfiguration = Get-SCVirtualHardDiskConfiguration -VMConfiguration $virtualMachineConfiguration
    $VHDConfiguration = $VHDConfiguration[2]
    Set-SCVirtualHardDiskConfiguration -VHDConfiguration $VHDConfiguration -PinSourceLocation $false -DestinationLocation "C:\ClusterStorage\$($server.replace($ServersNamePrefix,"Volume"))\" -FileName "$($server)_disk_3" -StorageQoSPolicy $null -DeploymentOption "None"
    $VHDConfiguration = Get-SCVirtualHardDiskConfiguration -VMConfiguration $virtualMachineConfiguration
    $VHDConfiguration = $VHDConfiguration[3]
    Set-SCVirtualHardDiskConfiguration -VHDConfiguration $VHDConfiguration -PinSourceLocation $false -DestinationLocation "C:\ClusterStorage\$($server.replace($ServersNamePrefix,"Volume"))\" -FileName "$($server)_disk_4" -StorageQoSPolicy $null -DeploymentOption "None"
    $VHDConfiguration = Get-SCVirtualHardDiskConfiguration -VMConfiguration $virtualMachineConfiguration
    $VHDConfiguration = $VHDConfiguration[4]
    Set-SCVirtualHardDiskConfiguration -VHDConfiguration $VHDConfiguration -PinSourceLocation $false -DestinationLocation "C:\ClusterStorage\$($server.replace($ServersNamePrefix,"Volume"))\" -FileName "$($server)_disk_5" -StorageQoSPolicy $null -DeploymentOption "None"


    Update-SCVMConfiguration -VMConfiguration $virtualMachineConfiguration
    New-SCVirtualMachine -Name "$Server" -VMConfiguration $virtualMachineConfiguration -Description "S2D deployment test" -BlockDynamicOptimization $false -JobGroup "$jobId" -StartAction "NeverAutoTurnOnVM" -StopAction "SaveVM" -RunAsynchronously

}

#verify status of deployment jobs.
$jobs = Get-SCJob | Where-Object {($_.Name -like "Create virtual machine*") -and ($_.StartTime -le (get-date).AddMinutes(10))}| Sort-Object Name
foreach ($Job in $jobs) {
    If ($job.status -eq "Running") {
        Write-Output "Waiting for Deployment to finnish to Finish"
        do {
            [System.Console]::Write("Progress {0}`r", $job.Progress)
            Start-Sleep 5
        } until (($job.status -eq "Completed") -or ($job.status -eq "Failed"))
    }
    #if ($job.status -eq "Completed") {
    #    Write-Output "Job Finished"
    #}
    #if ($job.status -eq "failed") {
    #    Write-Error "Job Failed"
    #}
}

#Clean up HardwareProfile
foreach ($server in $servers) {
    Get-SCHardwareProfile -All | Where-Object {$_.Name -eq "Profile$server"} | Remove-SCHardwareProfile
}

#Enable Nested Virtualization
foreach ($server in $servers) {
    $VM = Get-SCVirtualMachine -VMMServer localhost -Name $server
    Set-SCVirtualMachine -VM $VM -Name $server -RunAsSystem -UseHardwareAssistedVirtualization $true -EnableNestedVirtualization $true
    Start-SCVirtualMachine -VM $server
}

#Enable Network Teaming on VM's
Invoke-Command -ComputerName $PhysicalHosts -ScriptBlock { 
    Set-VMNetworkAdapter -VMName "S2D*" -Name NIC2 -AllowTeaming On -MacAddressSpoofing On
}
Start-Sleep -Seconds 15
Invoke-Command -ComputerName $PhysicalHosts -ScriptBlock { 
    Set-VMNetworkAdapterVlan -VMName "S2D*" -VMNetworkAdapterName NIC2 -Trunk -AllowedVlanIdList 10-50 -NativeVlanId 1  
}

Clear-DnsClientCache
#Wait for VM's to come online
Start-Sleep -Seconds 30

#Install Windows Features
foreach ($server in $servers) {
    Invoke-Command -ComputerName $server -ScriptBlock {
        Write-Verbose -Message "Enable Remoting"
        Enable-WSManCredSSP -Role Server -Force
        Enable-PSRemoting -Force
        Get-NetFirewallRule -Name *FPS* | Enable-NetFirewallRule
        Get-NetFirewallRule -Name Remotedes* | Enable-NetFirewallRule

        Write-Verbose -Message "Adding Windows Features"
        Install-WindowsFeature RSAT-Clustering-PowerShell, Windows-Defender-Features, Windows-Defender
        Install-WindowsFeature Failover-Clustering -IncludeAllSubFeature -IncludeManagementTools
        Install-WindowsFeature -Name Hyper-V, File-Services -IncludeManagementTools
    }
}

#Reboot nodes for Windows Features
foreach ($server in $servers) {
    Restart-Computer -ComputerName $server -Protocol WSMan -Wait -Force -Timeout 180 -Delay 5

}

#Install remaining config
foreach ($server in $servers) {
    #Seperate config for Windows Server 2016 and Insider Build's that do not support VMM
    IF (Get-SCVirtualMachine -Name $server | Where-Object {$_.OperatingSystem -eq "Windows Server 2016 Datacenter"}) {
        Invoke-Command -ComputerName $server -ScriptBlock {
            #Remove SMB1
            Write-Verbose -Message "Removing SMB1"
            Get-WindowsFeature -Name "FS-SMB1" | Remove-WindowsFeature -Confirm:$false -Remove
        }
    }
    #InsiderBuilds
    else {
        Invoke-Command -ComputerName $server -ScriptBlock {
            Install-WindowsFeature -Name FS-Data-Deduplication -IncludeAllSubFeature
        }
    }
}
#Restart after installing features
foreach ($server in $servers) {
    Restart-Computer -ComputerName $server -Protocol WSMan -Wait -Force -Timeout 60 -Delay 2

}


#Configure setswitch for vm's
foreach ($server in $servers) {
        
    Invoke-Command -ComputerName $server -ScriptBlock { 
        #Rename NIC's
        Get-NetAdapterAdvancedProperty  | Where-Object {$_.DisplayValue -eq "NIC1"} | Rename-NetAdapter -NewName NIC1
        Get-NetAdapterAdvancedProperty  | Where-Object {$_.DisplayValue -eq "NIC2"} | Rename-NetAdapter -NewName NIC2

        #Create new VMSwitch
        New-VMSwitch –Name S2DSwitch –NetAdapterName "NIC2" -EnableEmbeddedTeaming $true -AllowManagementOS $false
           
        #Configure Hyper-V Port Load Balancing algorithm (in 1709 its already Hyper-V, therefore setting only for Windows Server 2016)
        if ((Get-ItemPropertyValue -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\' -Name CurrentBuildNumber) -eq 14393) {
            Set-VMSwitchTeam -Name S2DSwitch -LoadBalancingAlgorithm HyperVPort
        }
        #Add Virtual Nics
        Add-VMNetworkAdapter –ManagementOS –Name MGMT –SwitchName S2DSwitch
        Add-VMNetworkAdapter -ManagementOS -Name SMB1 -SwitchName S2DSwitch
        Add-VMNetworkAdapter -ManagementOS -Name SMB2 -SwitchName S2DSwitch

        #Configure the host vNIC to use a Vlan.  They can be on the same or different VLans 
        Set-VMNetworkAdapterVlan -VMNetworkAdapterName MGMT -VlanId $Using:MGMTVLAN -Access -ManagementOS
        Set-VMNetworkAdapterVlan -VMNetworkAdapterName SMB1 -VlanId $Using:StorageVlan -Access -ManagementOS
        Set-VMNetworkAdapterVlan -VMNetworkAdapterName SMB2 -VlanId $Using:StorageVlan -Access -ManagementOS

    }
}
#Clear DNS and Wait for servers to get up from new setswitch
Clear-DnsClientCache
Start-Sleep -Seconds 30
Clear-DnsClientCache

#Set IP adresses on NIC's
$Servers | ForEach-Object {        

        
    #configure IP Addresses
    New-NetIPAddress -IPAddress ($MGMTNet + $MGMTStartIP.ToString()) -InterfaceAlias "vEthernet (MGMT)" -PrefixLength 24 -DefaultGateway 10.0.0.138 -CimSession $_
    $MGMTStartIP++
    New-NetIPAddress -IPAddress ($StorNet + $StorStartIP.ToString()) -InterfaceAlias "vEthernet (SMB1)" -PrefixLength 24 -CimSession $_
    $StorStartIP++
    New-NetIPAddress -IPAddress ($StorNet + $StorStartIP.ToString()) -InterfaceAlias "vEthernet (SMB2)" -PrefixLength 24 -CimSession $_
    $StorStartIP++
}

foreach ($server in $servers) {
    Invoke-Command -ComputerName $server -ScriptBlock {        
        #Set rest of config for Nic's 
        Set-DnsClientServerAddress -InterfaceAlias "*MGMT*" -ServerAddresses ("$Using:DNSServer1", "$Using:DNSServer2")
        Get-NetAdapter -Name "*MGMT*"| Set-DNSClient –RegisterThisConnectionsAddress $true
  
        #Start-Sleep -Seconds 30
        #Clear-DnsClientCache

        #Set Jumbo Frames on interfaces to lighten load on CPU
        Get-NetAdapterAdvancedProperty -DisplayName “Jumbo Packet” | Set-NetAdapterAdvancedProperty –DisplayValue “9014 Bytes”
        Set-NetAdapterAdvancedProperty -Name "NIC*" –DisplayName “Jumbo Packet” –DisplayValue “9014 Bytes”

        ##Enable LARGE SEND OFFLOAD
        Write-Verbose -Message "Enable LARGE SEND OFFLOAD"
        Get-NetAdapterLso | Enable-NetAdapterLso

        #Set Live Migration
        Write-Verbose -Message "Configure Live Migration"
        Enable-VMMigration
        Set-VMHost -MaximumVirtualMachineMigrations 20 -MaximumStorageMigrations 2 -VirtualMachineMigrationPerformanceOption SMB -VirtualMachineMigrationAuthenticationType Kerberos -EnableEnhancedSessionMode $true -UseAnyNetworkForMigration $true
        
        #Disable DNS registration on other nics.
        Write-Verbose -Message "Disable DNS Client on everything else than Management interface"
        Get-DnsClient | Where-Object {$_.InterfaceAlias -notlike "*MGMT*"} | Set-DnsClient -RegisterThisConnectionsAddress:$false
        ipconfig /registerdns
    }
}

Start-Sleep -Seconds 30
Clear-DnsClientCache
Start-Sleep -Seconds 30
Clear-DnsClientCache

#Add nic2 to set switch and configure Trunk tagging on NIC1
Invoke-Command -ComputerName $PhysicalHosts -ScriptBlock { 
    Set-VMNetworkAdapter -VMName "S2D*" -Name NIC1 -AllowTeaming On -MacAddressSpoofing On
}
Start-Sleep -Seconds 15
Invoke-Command -ComputerName $PhysicalHosts -ScriptBlock { 
    Set-VMNetworkAdapterVlan -VMName "S2D*" -VMNetworkAdapterName NIC1 -Trunk -AllowedVlanIdList 10-50 -NativeVlanId 1    
}

foreach ($server in $servers) {
    Invoke-Command -ComputerName $server -ScriptBlock { 
        $VMSwitch = Get-VMSwitch -Name S2DSwitch
        Add-VMSwitchTeamMember -VMSwitch $VMSwitch -NetAdapterName "NIC1"
    }
}

#Map SMB nic's to physical net adapters
foreach ($server in $servers) {
    Invoke-Command -ComputerName $server -ScriptBlock {
        $physicaladapters = (get-vmswitch S2DSwitch).NetAdapterInterfaceDescriptions | Sort-Object
        Set-VMNetworkAdapterTeamMapping -VMNetworkAdapterName "*SMB1*" -ManagementOS -PhysicalNetAdapterName (get-netadapter -InterfaceDescription $physicaladapters[0]).name
        Set-VMNetworkAdapterTeamMapping -VMNetworkAdapterName "*SMB2*" -ManagementOS -PhysicalNetAdapterName (get-netadapter -InterfaceDescription $physicaladapters[1]).name
    }
}

#Test Cluster
Test-Cluster -Node $servers -Include "Storage Spaces Direct", Inventory, Network, "System Configuration"
#Create Cluster
New-Cluster -Name $ClusterName -Node $Servers –NoStorage -StaticAddress $ClusterIPs

#Disable CSV Balancer
(Get-Cluster $ClusterName).CsvBalancer = 0

#Configure Witness on DC
#Create new directory
$WitnessName = $Clustername + "Witness"
Invoke-Command -ComputerName $DC -ScriptBlock {param($WitnessName); new-item -Path c:\Shares -Name $WitnessName -ItemType Directory} -ArgumentList $WitnessName
$accounts = @()
$accounts += "pedersen\$ClusterName$"
$accounts += "pedersen\Domain Admins"
New-SmbShare -Name $WitnessName -Path "c:\Shares\$WitnessName" -FullAccess $accounts -CimSession $DC
#Set NTFS permissions 
Invoke-Command -ComputerName $DC -ScriptBlock {param($WitnessName); (Get-SmbShare "$WitnessName").PresetPathAcl | Set-Acl} -ArgumentList $WitnessName
#Set Quorum
Set-ClusterQuorum -Cluster $ClusterName -FileShareWitness "\\$DC\$WitnessName"

#Enable ClusterS2D
Enable-ClusterS2D -PoolFriendlyName 'S2D' -CimSession $ClusterName -confirm:0 -Verbose

#Create 1 Cluster Shared Volume pr S2D node

$Servers | ForEach-Object {
    New-Volume –StoragePoolFriendlyName S2D* -FriendlyName $_ -FileSystem CSVFS_ReFS -StorageTierFriendlyNames Capacity -StorageTierSizes 40GB -CimSession $_
}

