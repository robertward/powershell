# Set SNS Topic to push to for Script updates - You must launch the instance using an IAM Role with permissions to publish to SNS
$SNSTopic = "arn:aws:sns:us-east-1:448705856127:Domain_Complete"
$SNSRegion = "us-east-1"

# Domain variables
$Domain = "example.com"
$DomainNetBIOS = "example"
$DomainUser = "DCAdmin"
$ComputerName = "DC1"

# Sets both User and Recovery Password
$DomainPassword = "Password123"

# Set Domain and Forest Mode
#     -- Windows Server 2003: 2 or Win2003
#     -- Windows Server 2008: 3 or Win2008
#     -- Windows Server 2008 R2: 4 or Win2008R2
#     -- Windows Server 2012: 5 or Win2012
#     -- Windows Server 2012 R2: 6 or Win2012R2
[string]$Mode = "4"

# ec2config blocks the serial port, gotta stop it
net stop ec2config
$port= new-Object System.IO.Ports.SerialPort COM1,9600,None,8,one
$port.open()

function Run-Script {
	$EC2SettingsFile="C:\Program Files\Amazon\Ec2ConfigService\Settings\Config.xml"
	$xml = [xml](get-content $EC2SettingsFile)
	$xmlElement = $xml.get_DocumentElement()
	$xmlElementToModify = $xmlElement.Plugins

	foreach ($element in $xmlElementToModify.Plugin)
	{
		if ($element.name -eq "Ec2HandleUserData")
		{
			$element.State="Enabled"
		}
	}
	$xml.Save($EC2SettingsFile)
}

function Step-One {
	Publish-SNSMessage -TopicArn $SNSTopic -Message "Script Step 1" -Region $SNSRegion
	$port.WriteLine("$(Get-Date -f 'u'): Script Step 1")
	Set-content -path C:\AD.log -value "1"
	Run-Script
	$netip = Get-NetIPConfiguration
	$ipconfig = Get-NetIPAddress | ?{$_.IpAddress -eq $netip.IPv4Address.IpAddress}
	Get-NetAdapter | Set-NetIPInterface -DHCP Disabled
	Get-NetAdapter | New-NetIPAddress -AddressFamily IPv4 -IPAddress $netip.IPv4Address.IpAddress -PrefixLength $ipconfig.PrefixLength -DefaultGateway $netip.IPv4DefaultGateway.NextHop
	Get-NetAdapter | Set-DnsClientServerAddress -ServerAddresses $netip.DNSServer.ServerAddresses
	Rename-Computer -NewName $ComputerName -Restart
}

function Step-Two {
	Publish-SNSMessage -TopicArn $SNSTopic -Message "Script Step 2" -Region $SNSRegion
	$port.WriteLine("$(Get-Date -f 'u'): Script Step 2")
	Set-content -path C:\AD.log -value "2"
	Run-Script
	Install-WindowsFeature AD-Domain-Services, rsat-adds -IncludeAllSubFeature
	Install-ADDSForest -DomainName $Domain -SafeModeAdministratorPassword (ConvertTo-SecureString $DomainPassword -AsPlainText -Force) -DomainMode $Mode -DomainNetbiosName $DomainNetBIOS -ForestMode $Mode -Confirm:$false -Force
}

function Step-Three {
	Publish-SNSMessage -TopicArn $SNSTopic -Message "Script Step 3" -Region $SNSRegion
	$port.WriteLine("$(Get-Date -f 'u'): Script Step 3")
	Set-content -path C:\AD.log -value "3"
	$UPN = $DomainUser + "@" + $Domain
	New-ADUser -Name $DomainUser -UserPrincipalName $UPN -AccountPassword (ConvertTo-SecureString $DomainPassword -AsPlainText -Force) -Enabled $true -PasswordNeverExpires $true
	Add-ADGroupMember 'Domain Admins' -Members $DomainUser
	Publish-SNSMessage -TopicArn $SNSTopic -Message "Script Complete" -Region $SNSRegion
	$port.WriteLine("$(Get-Date -f 'u'): Script Complete")
	$port.close()
	net start ec2config
	Restart-Computer
}

if (Test-Path C:\AD.log){
	$step = Get-Content C:\AD.log
	switch ($step){
		1 {Step-Two}
		2 {Step-Three}
		3 {Write-Host "Done"}
		default {Write-Host "Something is wrong"}
	}
}else{
	Publish-SNSMessage -TopicArn $SNSTopic -Message "Script Started" -Region $SNSRegion
	$port.WriteLine("$(Get-Date -f 'u'): Script Started")
	tzutil.exe /s 'Pacific Standard Time'
	New-NetFirewallRule -DisplayName "Allow Ping" -Direction Inbound -Action Allow -Protocol icmpv4 -Enabled True
	Step-One
}