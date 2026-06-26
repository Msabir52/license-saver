function Get-InactiveLicensedUser {
    param (
        [array]$LicensedUsers,
        [hashtable]$SkuLookup,
        [hashtable]$SkuPriceLookup,
        [int[]]$InactiveDays
    )

    # CORE REQUIREMENT 2 (#5 in readme tho) - ACTIVE LICENSED USERS WITH NO SIGN-IN IN X DAYS

    $inactiveLicensedUsers = @()

    #no longer only passing one number and now its an array so this is unneeded and doesnt work
    #$inactiveCutoffDate = (Get-Date).AddDays(-$InactiveDays)

    # Sort thresholds from biggest to smallest.
    # This lets us label a 100-day inactive user as 90+ instead of 30+.
    $sortedInactiveDays = $InactiveDays | Sort-Object -Descending

    Write-Log "Checking inactive users for thresholds: $($InactiveDays -join ', ') days"

    foreach ($user in $LicensedUsers) {
        #skip disabled users
        if ($user.accountEnabled -eq $false) {
            continue
        }

        $lastSignInRaw = $user.signInActivity.lastSignInDateTime

        $savings = Get-LicenseSavingsEstimate `
            -AssignedLicenses $user.assignedLicenses `
            -SkuLookup $SkuLookup `
            -SkuPriceLookup $SkuPriceLookup

        if (-not $lastSignInRaw) {
            $inactiveUser = [PSCustomObject]@{
                FindingType        = "InactiveUser"
                ThresholdDays     = "Manual Review"
                DisplayName       = $user.displayName
                UserPrincipalName = $user.userPrincipalName
                Licenses          = $savings.LicenseList
                LastSignIn        = "No sign-in data returned"
                DaysInactive      = "Unknown"
                Evidence          = "Microsoft Graph did not return a last sign-in date. $($savings.PriceEvidence)"
                Recommendation    = "Review account manually and consider reclaiming license if unused."
                MonthlySavings    = $savings.MonthlySavings
                AnnualSavings     = $savings.AnnualSavings
                MonthlySavingsText = $savings.MonthlySavingsText
                AnnualSavingsText  = $savings.AnnualSavingsText
                PriceEvidence      = $savings.PriceEvidence
            }

            $inactiveLicensedUsers += $inactiveUser
            continue
        }

        $lastSignInDate = [datetime]$lastSignInRaw
        $daysInactive = ((Get-Date) - $lastSignInDate).Days

        $matchedThreshold = $null

        foreach ($days in $sortedInactiveDays) {
            if ($daysInactive -ge $days) {
                $matchedThreshold = $days
                break
            }
        }

        if ($matchedThreshold) {
            $inactiveUser = [PSCustomObject]@{
                FindingType        = "InactiveUser"
                ThresholdDays     = $matchedThreshold
                DisplayName       = $user.displayName
                UserPrincipalName = $user.userPrincipalName
                Licenses          = $savings.LicenseList
                LastSignIn        = $lastSignInDate
                DaysInactive      = $daysInactive
                Evidence          = "Last sign-in was $daysInactive days ago. $($savings.PriceEvidence)"
                Recommendation    = "Review account manually and consider reclaiming license if unused."
                MonthlySavings    = $savings.MonthlySavings
                AnnualSavings     = $savings.AnnualSavings
                MonthlySavingsText = $savings.MonthlySavingsText
                AnnualSavingsText  = $savings.AnnualSavingsText
                PriceEvidence      = $savings.PriceEvidence
            }

            $inactiveLicensedUsers += $inactiveUser
        }
    }

    Write-Log "$($inactiveLicensedUsers.Count) inactive licensed users found across thresholds: $($InactiveDays -join ', ') days"

    return $inactiveLicensedUsers
}
