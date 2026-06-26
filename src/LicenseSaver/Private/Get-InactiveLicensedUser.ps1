function Get-InactiveLicensedUser {
    param (
        [array]$LicensedUsers,
        [hashtable]$SkuLookup,
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

        $licenseList = Get-ReadableLicenseList `
            -AssignedLicenses $user.assignedLicenses `
            -SkuLookup $SkuLookup

        if (-not $lastSignInRaw) {
            $inactiveUser = [PSCustomObject]@{
                ThresholdDays     = "Manual Review"
                DisplayName       = $user.displayName
                UserPrincipalName = $user.userPrincipalName
                Licenses          = $licenseList
                LastSignIn        = "No sign-in data returned"
                DaysInactive      = "Unknown"
                Evidence          = "Microsoft Graph did not return a last sign-in date."
                Recommendation    = "Review account manually and consider reclaiming license if unused."
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
                ThresholdDays     = $matchedThreshold
                DisplayName       = $user.displayName
                UserPrincipalName = $user.userPrincipalName
                Licenses          = $licenseList
                LastSignIn        = $lastSignInDate
                DaysInactive      = $daysInactive
                Evidence          = "Last sign-in was $daysInactive days ago."
                Recommendation    = "Review account manually and consider reclaiming license if unused."
            }

            $inactiveLicensedUsers += $inactiveUser
        }
    }

    Write-Log "$($inactiveLicensedUsers.Count) inactive licensed users found across thresholds: $($InactiveDays -join ', ') days"

    return $inactiveLicensedUsers
}