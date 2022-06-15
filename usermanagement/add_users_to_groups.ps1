# adds an array of users to a group or groups

# import active directory module
try {
    Import-Module ActiveDirectory -ErrorAction Stop
    Write-Host 'Active Directory module imported' -ForegroundColor Green
} catch {
    Write-Host 'Active Directory module not imported' -ForegroundColor Red
    Write-Host 'Remote Server Administration Tools for Active Directory must be installed' -ForegroundColor Red
    Write-Log $_ $errorlog
}

# list is the samAccountName or distinguished name of each user on a separate line
$list = Get-Content userlist.txt
# groups are the name of the group as a string. separate with commas
$groups = @(
    'cx.pericalm.testing'
)

foreach ( $user in $list ) {
    $aduser = Get-ADUser -Filter { samaccountname -like $user }
    Add-ADPrincipalGroupMembership -Identity $aduser -MemberOf $groups
}