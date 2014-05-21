foreach ($drive in Get-WmiObject Win32_logicaldisk | Where-Object {$_.DriveType -like 3}){
	if ($drive.DeviceID -ne "C:"){
		$dir = $drive.DeviceID + "\Windows\System32\config\SYSTEM"
		reg load HKLM\RECOVERY $dir | Out-Null
		$regkey = "HKLM:\RECOVERY\ControlSet001\Services\rhelscsi"
		if (Test-Path $regkey){
			Set-ItemProperty -Path $regkey -name EnumerateDevices -value 1
			Write-Host "Redhat Drivers re-enabled"
			"select disk 1", "offline disk" | diskpart | Out-Null
			Write-Host "Drive offline"
		}else{
			Write-Host "Redhat drivers not installed"
		}
		[gc]::collect()
		reg unload HKLM\RECOVERY | Out-Null
	}
}