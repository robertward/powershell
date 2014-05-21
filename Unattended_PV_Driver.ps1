
# Enable ping responses
netsh firewall set icmpsetting 8

# Make sure directories exist
$dirs = @("C:\AWS\Download", "C:\AWS\Log", "C:\AWS\Bin")
foreach ($dir in $dirs){
	if (Test-Path $dir){
	}else{
		New-Item $dir -type Directory
	}
}

# List the needed update files, download them and unzip
$zips = @(
 'http://s3.amazonaws.com/ec2-downloads-windows/EC2Config/EC2Install.zip',
 'http://s3.amazonaws.com/ec2-downloads-windows/Drivers/Citrix-Win_PV.zip',
 'http://s3.amazonaws.com/ec2-downloads-windows/AWSDiagnostics/AWSDiagnostics.zip'
)
foreach ($file in $zips){
	$path = $dirs[0] + ($file -replace ".*\/","\")
	Invoke-WebRequest $file -Outfile $path
	$shell_app=new-object -com shell.application
	$zip_file = $shell_app.namespace($path)
	$destination = $shell_app.namespace($dirs[2])
	# extract zip to $CurrentLocation with silent (0x04) overwrite (0x10)
	$destination.Copyhere($zip_file.items(),0x14)
}

# Trick Upgrade script
Set-Location ($dirs[2] + "\Citrix-Win_PV")
Move-Item PVRedhatToCitrixUpgrade.ps1 manual-PVRedhatToCitrixUpgrade.ps1
Get-Content manual-PVRedhatToCitrixUpgrade.ps1 | % { $_ -replace ".*answerResult = .answer.popup.*","`$answerResult = 6" } > PVRedhatToCitrixUpgrade.ps1

# Watch for uninst.exe and click Yes on prompt
cmd /C start powershell -ExecutionPolicy Bypass -NoExit -Command {
	while($true){
		$uninstProc = get-process -name uninst -ErrorAction SilentlyContinue
		$procID = $uninstProc.id

		# Create Shell Control object
		$wshell = new-object -com wscript.shell

		# Activate Window by ID
		$wshell.appActivate($procID)

		# Send command [ ALT + Y ]
		$wshell.sendKeys("%y")
		
		Start-Sleep 30
	}
}

# Update EC2Config
Start-Process -FilePath ($dirs[2] + "\EC2Install\EC2Install.exe") -ArgumentList "/install /norestart /log c:\aws\log\$ec2file.txt /quiet " -Wait -WorkingDirectory ($dirs[2] + "\EC2Install")

# Update PV drivers
Start-Process -FilePath ($dirs[2] + "\Citrix-Win_PV\Upgrade.bat") -ArgumentList "/c" -Wait -WorkingDirectory ($dirs[2] + "\Citrix-Win_PV")