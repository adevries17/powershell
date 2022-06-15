# Searches for IIS servers and clears logs older than specified date in the variable of $timespan

# import additional functions
Import-Module .\functions.psm1  # import external functions found in the functions.psm1 file

# set variables
$timespan = (Get-date).AddDays(-60) # change this number to adjust the length of time
$ErrorActionPreference = 'SilentlyContinue'      # adjust error action behavior
$searchbase = 'ou=servers,ou=epic,dc=riversidehealthcare,dc=net' # active directory path to search. can be base dn

# gather data from active directory
Get-ADComputer -SearchBase $searchbase -Filter {OperatingSystem -like "*Windows Server*" -and Enabled -eq $true} |
    Select-object DistinguishedName,Name | Export-Csv -NoTypeInformation .\serverlist.csv #get active directory computers based upon filter statement
# perform ping tests on computers defined in .\serverlist.csv
$serverlist =Import-Csv .\serverlist.csv
foreach ($server in $serverlist){
    $onlinetest = Test-NetConnection -ComputerName $server.Name #ping with icmp
    $onlinetest | Select-Object computername,remoteaddress,pingsucceeded | Export-Csv -Append -NoTypeInformation .\serverlistpingd.csv #select properties and output to new csv file
}
# detect IIS application for pingable devices
# this section taken from https://briangordon.wordpress.com/2010/10/27/powershell-check-if-iis-is-running-on-a-remote-server/
$pingservers =Import-Csv .\serverlistpingd.csv #import list of pinged servers
foreach ($server in $pingservers){
    $iisstat =Get-WmiObject Win32_Service -ComputerName $($server.computername) -Filter "name='IISADMIN' OR name='W3SVC'" #get IIS service state
    if ($iisstat.State -eq 'Running'){
        Write-Host "IIS is running on $($server.ComputerName)" #write to console
        Add-Content .\iisservers.txt -Value $($server.ComputerName) #list out all iis servers for later use
    } else {Write-Host "IIS not running on $($server.ComputerName)"}
}
# for detected IIS installs clear the logs older than $timespan
$iislogpath = '\c$\inetpub\logs\LogFiles\W3SVC1' #default IIS log path
$iisservers = $null #just in case extra bits got in there
$iisservers = Get-Content .\iisservers.txt
foreach ($web in $iisservers){
    try {
        $cleanuppath =('\\'+$web+$iislogpath)
        New-PSDrive -Name I -PSProvider FileSystem -Root $cleanuppath #create psdrive for easy access using alternate credentials
        Remove-File -Path I: -Cutoff $timespan -WhatIf #using function from the module import
        Remove-PSDrive -Name I #remove psdrive after use
    } catch {
        Write-Host "Logs were not cleaned on $web"
        Write-Error | Tee-Object errors.log -Append
    }
}