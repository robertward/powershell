Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Force

# AWS PowerShell modules need to be imported to allow the AWS specific cmdlets to run properly.
#Import-Module AWSPowerShell

# Enter 12-digit AWS Account ID if you wish to specify the account. You can simply call "self" instead of defining the ID here.
$Owner = "self"

# Enter the region where you want to create your AMIs. The script is defaulting to North Virginia (us-east-1), though you can enter any of the following:
# North California (us-west-1), Oregon (us-west-2), Ireland (eu-west-1), Tokyo (ap-northeast-1), Singapore (ap-southeast-1), Sydney (ap-southeast-2), São Paulo (sa-east-1)
$Region = "eu-west-1"

# This variable is getting all instances in an account and region. The Get-EC2Instance does not return instance IDs, but Get-EC2Tag does.
# Comment this list if you choose to define your own set of instances in $Instances (see below).
$EC2Instance = Get-EC2Instance -Region $Region

# An array is created from $EC2Instance. This will grab all instances. Comment out the array below if you would would rather create AMIs from a small number of instances.
$Instance = $EC2Instance.Instances

# Checks AMI age. If it's less than 7 days old, it will be unregistered.

# Get today's date in yyyy-MM-dd format and create date object
$todaysDate = [System.DateTime] (Get-Date -Format 'yyyy-MM-dd')

foreach ($AMI in Get-EC2Image -Region $Region -Owner self){
	#Get Date from AMI
    $amiDate = Get-Date $AMI.Description
    #unregister older images if date seven days ago is greater than the AMI description
    if ( $todaysDate.AddDays(-7) -gt $amiDate){
	
    $ImageID = $AMI.ImageId
    Unregister-EC2Image -ImageId $ImageID -Region $Region

    }
}

foreach ($running in Get-EC2Instance -Region $Region){
	if ($running.Instances.state.name -eq "running"){
	[string]$name = $running.Instances.InstanceId
		New-EC2Image -InstanceId $name -Name $name -Description (Get-Date) -Region $Region
	}
}
