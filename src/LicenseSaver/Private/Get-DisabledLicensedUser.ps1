function Get-DisabledLicensedUser {
    param (
        [array]$LicensedUsers
    )

    #TRUCKING ALONG WITH THE FIRST CORE REQUIREMENT - UNLICENSING DISABLED ACCOUNTS

    $disabledLicensedUsers = @()

    foreach ($user in $LicensedUsers) {
        if ($user.accountEnabled -eq $false) {
            $disabledLicensedUsers += $user
        }
    }

    return $disabledLicensedUsers
}