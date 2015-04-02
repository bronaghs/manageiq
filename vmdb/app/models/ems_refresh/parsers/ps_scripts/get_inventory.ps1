import-module virtualmachinemanager

function get_vms{
 $vms = $args[0]
 $results = @{}
 $vms | ForEach-Object {
  $vm_hash = @{}
  $vm_props = @{}
  $id = $_.ID
  $vm_props["Name"] = $_.Name
  $vm_props["ComputerName"] = $_.ComputerName
  $vm_props["ID"] = $_.ID
  $vm_props["ServerConnection"] = $_.ServerConnection.IsConnected
  $vm_props["HostName"] = $_.HostName
  $vm_props["VirtualMachineState"]  = $_.VirtualMachineState
  $vm_props["OperatingSystem"]  = $_.OperatingSystem
  $vm_props["VMCPath"] = $_.VMCPath
  $vm_props["OperatingSystemShutdownEnabled"] = $_.OperatingSystemShutdownEnabled
  $vm_props["TimeSynchronizationEnabled"]   = $_.TimeSynchronizationEnabled
  $vm_props["DataExchangeEnabled"] = $_.DataExchangeEnabled
  $vm_props["BackupEnabled"] = $_.BackupEnabled
  $vm_props["HeartbeatEnabled"]   = $_.HeartbeatEnabled
  $vm_props["Memory"]= $_.Memory
  $vm_props["CPUCount"]= $_.CPUCount
  $vm_props["CPUType"]= $_.CPUType
  $vm_props["VirtualDVDDrives"]= $_.VirtualDVDDrives
  $vm_props["BiosGuid"]= $_.BiosGuid
  $vm_props["LastRestoredVMCheckpoint"]= $_.LastRestoredVMCheckpoint
  $vm_props["VMCheckpoints"]= $_.VMCheckpoints

  $vm_props["VirtualHardDisks"] = @(Get-SCVirtualHardDisk -VM $_)
  $networks = Read-SCGuestInfo -VM $_ -Key "NetworkAddressIPv4" -ErrorAction SilentlyContinue
   if ($networks -ne $null){
    $vm_props["Networks"] = $networks.KvpMap["NetworkAddressIPv4"]
   }

  $vm_hash["Properties"] = $vm_props

  $results[$id]= $vm_hash
 }
 return $results
}


$file = [System.IO.Path]::GetTempFileName()
$r = @{}
$v = Get-SCVirtualMachine -VMMServer "localhost"
$r["vms"] = get_vms($v)

$r | Export-CLIXML -path $file -encoding UTF8
get-content $file
$file.close
