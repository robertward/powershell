$root = 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Class\{4D36E972-E325-11CE-BFC1-08002BE10318}'
$items = Get-ChildItem -Path Registry::$Root -Name
 
Foreach ($item in $items) {
	if ($item -ne "Properties") {
		$path = $root + "\" + $item
		$DriverDesc = Get-ItemProperty -Path Registry::$path | Select-Object -expandproperty DriverDesc
		if ($DriverDesc -eq "Citrix PV Ethernet Adapter") {
			Set-ItemProperty -path Registry::$path -Name LROIPv4 -Value 0
			Set-ItemProperty -path Registry::$path -Name *IPChecksumOffloadIPv4 -Value 0
			Set-ItemProperty -path Registry::$path -Name *TCPChecksumOffloadIPv4 -Value 0
			Set-ItemProperty -path Registry::$path -Name *LSOv2IPv4 -Value 0
		}
	}
}
 
Restart-NetAdapter -Name Ethernet