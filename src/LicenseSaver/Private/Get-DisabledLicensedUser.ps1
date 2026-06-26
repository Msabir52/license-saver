function Get-DisabledLicensedUser {
    param (
        [array]$LicensedUsers,
        [hashtable]$SkuLookup,
        [hashtable]$SkuPriceLookup
    )

    #TRUCKING ALONG WITH THE FIRST CORE REQUIREMENT - UNLICENSING DISABLED ACCOUNTS

    $disabledLicensedUsers = @()

    foreach ($user in $LicensedUsers) {
        if ($user.accountEnabled -eq $false) {
            $lastSignIn = $user.signInActivity.lastSignInDateTime

            if (-not $lastSignIn) {
                $lastSignIn = "No sign-in data returned"
            }

            $savings = Get-LicenseSavingsEstimate `
                -AssignedLicenses $user.assignedLicenses `
                -SkuLookup $SkuLookup `
                -SkuPriceLookup $SkuPriceLookup

            $disabledLicensedUsers += [PSCustomObject]@{
                FindingType        = "DisabledUser"
                DisplayName        = $user.displayName
                UserPrincipalName  = $user.userPrincipalName
                Licenses           = $savings.LicenseList
                LastSignIn         = $lastSignIn
                Evidence           = "Account is disabled but still has an assigned license. $($savings.PriceEvidence)"
                Recommendation     = "Review and consider reclaiming assigned license."
                MonthlySavings     = $savings.MonthlySavings
                AnnualSavings      = $savings.AnnualSavings
                MonthlySavingsText = $savings.MonthlySavingsText
                AnnualSavingsText  = $savings.AnnualSavingsText
                PriceEvidence      = $savings.PriceEvidence
            }
        }
    }

    return $disabledLicensedUsers
}
