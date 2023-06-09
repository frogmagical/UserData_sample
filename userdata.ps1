<userdata>
$ErrorActionPreference = "Stop"

#Set logging
function Logging($String){
    Write-Output "$(Get-Date -Format G): $String" | Out-File $logPath -Append
}

#Set params
$driveLetter = "D"
$Global:logPath = "C:/userdata/log/userdata.log"

#Check working dir
if (!(Test-path "C:/userdata/")){
    mkdir C:/userdata/
    mkdir C:/userdata/log
}
Set-Location "C:/userdata/"
Logging "Start Userdata"

#Set user credential 
#usernames and passwords had better other than Hard Coding :/
$uname = 'Administrator'
$pw = ConvertTo-SecureString -AsPlainText 'P@ssw0rd' -Force
$credential = New-Object system.Management.Automation.PSCredential $uname,$pw

#Check Userdata Status
try {
    $userDataStatus = (Invoke-RestMethod -uri http://169.254.169.254/latest/meta-data/tags/instance/UserDataStatus)
    if ($userDataStatus -ceq "Complete"){
        Logging "User data has been conducted!"
        exit
    }
} catch {
    #Create UserDataStatus tag
    Logging "***Info*** Create UserDataStatus tag (Unexecuted)"
    aws ec2 create-tags --resources $instanceID --tags "Key=UserDataStatus,Value=Unexecuted"
}

#Get EC2 tagdatas
Logging "Get tagdatas"
$instanceID = (Invoke-RestMethod -uri http://169.254.169.254/latest/meta-data/instance-id)
try {
    $hostName = (Invoke-RestMethod -uri http://169.254.169.254/latest/meta-data/tags/instance/HostName)
} catch {
    Logging "***ERROR*** Missing HostName tag"
}
try {
    [string]$phase1 = (Invoke-RestMethod -uri http://169.254.169.254/latest/meta-data/tags/instance/Phase1)
} catch {
    Logging "***Info*** Phase1 tag is missing but will be create and resume"
    aws ec2 create-tags --resources $instanceID --tags "Key=Phase1,Value=False"
}
try {
    [string]$phase2 = (Invoke-RestMethod -uri http://169.254.169.254/latest/meta-data/tags/instance/Phase2)
} catch {
    Logging "***Info*** Phase2 tag is missing but will be create and resume"
    aws ec2 create-tags --resources $instanceID --tags "Key=Phase2,Value=False"
}

#Phase skip
if ($phase1 -ceq "True"){
    Logging "Skip Phase1"
}

#Phase1
if ($phase1 -ceq "False"){
    Logging "Start Phase1"
    #Join Activedirectory
    Logging "Set new hostname"
    Rename-Computer -NewName $hostName -Force
    Logging "Start join ActiveDirectory"
    try {
        Add-computer example -OUPath 'OU=excomputers,DC=example,DC=com' -Credential $credential
        Logging "Complete join ActiveDirectory"
    } catch {
        Logging "**ERROR** Failuer join ActiveDirectory..."
        Logging $error[0]
    }
    #Set tag data
    Logging "Set tag status(Phase1)"
    aws ec2 create-tags --resources $instanceID --tags "Key=Phase1,Value=True"
    #Restart
    Logging "Complete Phase1"
    Logging "Restart Computer"
    Restart-Computer -Force
}

#Phase skip
if ($phase2 -ceq "True"){
    Logging "Skip Phase2"
}
#Phase2
if ($phase2 -ceq "False"){
    Logging "Start Phase2"
    #Attach FSx
    Logging "Start attach FSx"
    try {
        New-PSDrive -Name $driveLetter -PSProvider FileSystem -Root "<FSxPath>"
        Logging "Complete attach FSx"
    } catch {
        Logging "**ERROR** Failuer attach FSx..."
        Logging $error[0]
    }
    #IIS restart
    try {
        Logging "IIS restart"
        iisreset
        Logging "IIS restart complete"
    } catch {
        Logging "**ERROR** Failuer IIS restart..."
        Logging $error[0]
    }
    #Set tag data
    aws ec2 create-tags --resources $instanceID --tags "Key=Phase2,Value=True"
    Logging "Complete Phase2"
    #Restart (If need it then disable comment out next command-line.)
    #Restart-Computer
}

#Finishing
Logging "Complete Userdata!"
aws ec2 create-tags --resources $instanceID --tags "Key=UserDataStatus,Value=Complete"

</userdata>
<persist>true</persist>