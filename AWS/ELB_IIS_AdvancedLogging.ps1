# Select which site you wish to enable logging for
$site = "Default Web Site"

New-EventLog -Source RobWard -LogName Application

$xml = New-Object XML
$eventlog = "<?xml version=`"1.0`" standalone=`"yes`"?>
<EventLogConfig>
  <Event>
    <Category>Application</Category>
    <AppName>RobWard</AppName>
    <ErrorType>Information</ErrorType>
    <LastMessageTime>2013-01-01T00:00:00.0000000+00:00</LastMessageTime>
    <NumEntries>1</NumEntries>
  </Event>
</EventLogConfig>"

$eventlog | Out-File "C:\Program Files\Amazon\Ec2ConfigService\Settings\EventLogConfig.xml"
$xml.load("C:\Program Files\Amazon\Ec2ConfigService\Settings\EventLogConfig.xml")
$xml.save("C:\Program Files\Amazon\Ec2ConfigService\Settings\EventLogConfig.xml")
$xml.load("C:\Program Files\Amazon\Ec2ConfigService\Settings\config.xml")
$xml.Ec2ConfigurationSettings.Plugins.Plugin | Where-Object { $_.Name -eq 'Ec2EventLog'} | ForEach-Object { $_.State = 'Enabled' }
$xml.save("C:\Program Files\Amazon\Ec2ConfigService\Settings\config.xml")

Install-WindowsFeature Web-Server -IncludeManagementTools -IncludeAllSubFeature

Write-EventLog -LogName Application -Source RobWard -EventId 666 -EntryType Information -Message "IIS Installed"

mkdir c:\data
Invoke-WebRequest "http://download.microsoft.com/download/9/6/5/96594C39-9918-466C-AFE0-920737351987/AdvancedLogging64.msi" -OutFile C:\data\AdvancedLogging64.msi

msiexec.exe /i C:\data\AdvancedLogging64.msi /passive /log C:\Data\advancedlogging.log
Start-Sleep -Seconds 10

#grant permission to IIS_IUSERS group to the log directory
mkdir c:\logs
$Command = "icacls C:\logs /grant BUILTIN\IIS_IUSRS:(OI)(CI)RXMW"
cmd.exe /c $Command
$logDirectory = "C:\logs"

# Disables http logging module
Set-WebConfigurationProperty -Filter system.webServer/httpLogging -PSPath machine/webroot/apphost -Name dontlog -Value true

# Adds AWS ELB aware X-Forwarded-For logging field
Add-WebConfiguration "system.webServer/advancedLogging/server/fields" -value @{id="X-Forwarded-For";sourceName="X-Forwarded-For";sourceType="RequestHeader";logHeaderName="X-Forwarded-For";category="Default";loggingDataType="TypeLPCSTR"}

# Adds AWS ELB aware X-Forwarded-Proto logging field
Add-WebConfiguration "system.webServer/advancedLogging/server/fields" -value @{id="X-Forwarded-Proto";sourceName="X-Forwarded-Proto";sourceType="RequestHeader";logHeaderName="X-Forwarded-Proto";category="Default";loggingDataType="TypeLPCSTR"} 

# Disables the default advanced logging config
Set-WebConfigurationProperty -Filter "system.webServer/advancedLogging/server/logDefinitions/logDefinition[@baseFileName='%COMPUTERNAME%-Server']" -name enabled -value false

# Enable Advanced Logging
Set-WebConfigurationProperty -Filter system.webServer/advancedLogging/server -PSPath machine/webroot/apphost -Name enabled -Value true

# Set log directory at server level
Set-WebConfigurationProperty -Filter system.applicationHost/advancedLogging/serverLogs -PSPath machine/webroot/apphost -Name directory -Value $logDirectory

# Set log directory at site default level
Set-WebConfigurationProperty -Filter system.applicationHost/sites/siteDefaults/advancedLogging -PSPath machine/webroot/apphost -Name directory -Value $logDirectory


function AdvancedLogging-GenerateAppCmdScriptToConfigureAndRun()
{
	param([string] $site) 

	#Get current powershell execution folder
	$currentLocation = Get-Location

	#Create an empty bat which will be populated with appcmd instructions
	$stream = [System.IO.StreamWriter] "$currentLocation\$site.bat"

	#Create site specific log definition
	$stream.WriteLine("C:\windows\system32\inetsrv\appcmd.exe set config `"$site`" -section:system.webServer/advancedLogging/server /+`"logDefinitions.[baseFileName='$site',enabled='True',logRollOption='Schedule',schedule='Daily',publishLogEvent='False']`" /commit:apphost")

	#Get all available fields for logging
	$availableFields = Get-WebConfiguration "system.webServer/advancedLogging/server/fields"

	#Add appcmd instruction to add all the selected fields above to be logged as part of the logging
	#The below section can be extended to filter out any unwanted fields
	foreach ($item in $availableFields.Collection) 
	{
		$stream.WriteLine("C:\windows\system32\inetsrv\appcmd.exe set config `"$site`" -section:system.webServer/advancedLogging/server /+`"logDefinitions.[baseFileName='$site'].selectedFields.[id='$($item.id)',logHeaderName='$($item.logHeaderName)']`" /commit:apphost")
	}

	$stream.close()

	# execute the batch file create to configure the site specific Advanced Logging
	Start-Process -FilePath $currentLocation\$site.bat
	Start-Sleep -Seconds 10
}

#Call the above method by passing in the IIS site names
AdvancedLogging-GenerateAppCmdScriptToConfigureAndRun $site