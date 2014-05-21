
$diskDriveMap = @{
"0,0,0" = "Mount Point: sda1, Disk ID: 0"
}

98..122 | foreach-object {
$key = "0," + ($_ - 97) + ",0"
$value = "Mount Point: xvd" + [char]$_ + ", Disk ID: " + ($_ - 97)
$diskDriveMap.add($key, $value)
}

$computer = "."
$namespace = "root\CIMV2"

$citrixDrivers = gwmi -class Win32_PnPSignedDriver -computername $computer -namespace $namespace -Filter "DeviceName='Citrix PV SCSI Host Adapter'"
if ($citrixDrivers) {
  $ddrives = gwmi -class Win32_DiskDrive -computername $computer -namespace $namespace

  foreach ($ddrive in $ddrives) {
    $dkey = "" + $ddrive.SCSIBus + "," + $ddrive.SCSITargetId + "," + $ddrive.SCSILogicalUnit
    if ($diskDriveMap.ContainsKey($dkey)) {
      $diskInfo = $diskDriveMap[$dkey] + ", Volume(s): "
      $partitions = gwmi -Query "ASSOCIATORS OF {Win32_DiskDrive.DeviceID='$($ddrive.DeviceID)'} WHERE AssocClass = Win32_DiskDriveToDiskPartition"
      foreach ($partition in $partitions) {
        $ldisks = gwmi -Query "ASSOCIATORS OF {Win32_DiskPartition.DeviceID='$($partition.DeviceID)'} WHERE AssocClass = Win32_LogicalDiskToPartition"
        foreach ($ldisk in $ldisks) { $diskInfo += $ldisk.DeviceID }
      }
      write-host $diskInfo 
    } else {
      write-host "Unknown Disk Drive : " + $ddrive.DeviceID
    }
  }
} else {
  write-host "Unable to locate latest drivers. Cannot determine Disk Drive information."
}
