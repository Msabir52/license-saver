function New-LicenseHtmlReport {

    param (
        [array]$DisabledUsers,
        [array]$InactiveUsers,
        [array]$UnassignedLicenses,
        [string]$ReportPath,
        [hashtable]$SkuLookup,
        [int[]]$InactiveDays,
        [string]$TotalMonthlyWasteText,
        [string]$TotalAnnualWasteText,
        [string]$TotalMonthlySavingsText,
        [string]$TotalAnnualSavingsText
    )

    Write-Log "Building report"

    # DISABLED USERS TABLE ROWS
    $disabledRows = ""

    foreach ($user in $DisabledUsers) {

        $disabledRows += @"
        <tr>
            <td>$($user.DisplayName)</td>
            <td>$($user.UserPrincipalName)</td>
            <td>$($user.Licenses)</td>
            <td>$($user.LastSignIn)</td>
            <td>$($user.Evidence)</td>
            <td>$($user.Recommendation)</td>
            <td>$($user.MonthlySavingsText)</td>
            <td>$($user.AnnualSavingsText)</td>
        </tr>
"@
    }

    if ($DisabledUsers.Count -eq 0) {
        $disabledRows = @"
        <tr>
            <td colspan="8">No disabled users with active licenses were found.</td>
        </tr>
"@
    }

    # INACTIVE USERS TABLE ROWS
    $inactiveRows = ""

    foreach ($user in $InactiveUsers) {

        $inactiveRows += @"
        <tr>
            <td>$($user.ThresholdDays)+ days</td>
            <td>$($user.DisplayName)</td>
            <td>$($user.UserPrincipalName)</td>
            <td>$($user.Licenses)</td>
            <td>$($user.LastSignIn)</td>
            <td>$($user.DaysInactive)</td>
            <td>$($user.Evidence)</td>
            <td>$($user.Recommendation)</td>
            <td>$($user.MonthlySavingsText)</td>
            <td>$($user.AnnualSavingsText)</td>
        </tr>
"@
    }

    #ideal case :)
    if ($InactiveUsers.Count -eq 0) {
        $inactiveRows = @"
        <tr>
        <td colspan="10">No active licensed users inactive for these thresholds were found: $($InactiveDays -join ', ') days.</td>
        </tr>
"@
    }

    # UNASSIGNED LICENSE TABLE ROWS
$unassignedRows = ""

foreach ($license in $UnassignedLicenses) {

    $monthlyPrice = "Unknown"
    $monthlyWaste = "Unknown"
    $annualWaste = "Unknown"

    if ($null -ne $license.MonthlyPrice) {
        $monthlyPrice = '$' + $license.MonthlyPrice
    }

    if ($null -ne $license.MonthlyWaste) {
        $monthlyWaste = '$' + $license.MonthlyWaste
    }

    if ($null -ne $license.AnnualWaste) {
        $annualWaste = '$' + $license.AnnualWaste
    }

    $unassignedRows += @"
        <tr>
            <td>$($license.SkuPartNumber)</td>
            <td>$($license.TotalEnabled)</td>
            <td>$($license.Assigned)</td>
            <td>$($license.Available)</td>
            <td>$monthlyPrice</td>
            <td>$monthlyWaste</td>
            <td>$annualWaste</td>
            <td>$($license.Evidence)</td>
        </tr>
"@
}

if ($UnassignedLicenses.Count -eq 0) {
    $unassignedRows = @"
        <tr>
            <td colspan="8">No unassigned licenses were found.</td>
        </tr>
"@
}

$totalUnassignedSeats = 0

foreach ($license in $UnassignedLicenses) {
    $totalUnassignedSeats += $license.Available
}

    $html = @"
<!doctype html>
<html>
<head>
    <meta charset="utf-8">
    <title>Microsoft 365 License Report</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            margin: 30px;
        }

        h1 {
            margin-bottom: 5px;
        }

        .summary {
            margin: 15px 0;
            font-size: 18px;
            font-weight: bold;
        }

        .summary-box {
            border: 1px solid #cccccc;
            background-color: #f7f7f7;
            padding: 12px;
            margin-bottom: 25px;
        }

        table {
            border-collapse: collapse;
            width: 100%;
            margin-bottom: 30px;
        }

        th, td {
            border: 1px solid #cccccc;
            padding: 8px;
            text-align: left;
            vertical-align: top;
        }

        th {
            background-color: #eeeeee;
        }

        tr:nth-child(even) {
            background-color: #f7f7f7;
        }

        .note {
            margin-top: 20px;
            font-size: 13px;
        }
    </style>
</head>
<body>
    <h1>Microsoft 365 License Report</h1>

    <div class="summary-box">
        <div class="summary">$($DisabledUsers.Count) disabled users with active licenses found.</div>
        <div class="summary">$($InactiveUsers.Count) inactive-user findings across thresholds: $($InactiveDays -join ', ') days.</div>
        <div class="summary">$totalUnassignedSeats unassigned license seats found across $($UnassignedLicenses.Count) SKU(s).</div>
        <div class="summary">Total projected savings: $TotalMonthlySavingsText monthly / $TotalAnnualSavingsText annually.</div>
        <div class="summary">Projected unassigned-license waste: $TotalMonthlyWasteText monthly / $TotalAnnualWasteText annually.</div>
    </div>

    <h2>Disabled Users With Active Licenses</h2>

    <table>
        <thead>
            <tr>
                <th>Name</th>
                <th>UPN</th>
                <th>Licenses</th>
                <th>Last Sign-In</th>
                <th>Evidence</th>
                <th>Recommendation</th>
                <th>Projected Monthly Savings</th>
                <th>Projected Annual Savings</th>
            </tr>
        </thead>
        <tbody>
$disabledRows
        </tbody>
    </table>

    <h2>Inactive Licensed Users</h2>

    <table>
        <thead>
            <tr>
                <th>Threshold</th>
                <th>Name</th>
                <th>UPN</th>
                <th>Licenses</th>
                <th>Last Sign-In</th>
                <th>Days Inactive</th>
                <th>Evidence</th>
                <th>Recommendation</th>
                <th>Projected Monthly Savings</th>
                <th>Projected Annual Savings</th>
            </tr>
        </thead>
        <tbody>
$inactiveRows
        </tbody>
    </table>

    <div class="note">
        <strong>Methodology:</strong>
        Disabled licensed users are users where accountEnabled is false and assignedLicenses has one or more entries.
        Inactive licensed users are enabled licensed users where the last sign-in date is older than $InactiveDays days.
        Users with no sign-in data returned by Microsoft Graph are included for manual review.
    </div>

    <h2>Unassigned Licenses</h2>

    <table>
        <thead>
        <tr>
            <th>Sku Part Number</th>
            <th>Total Enabled</th>
            <th>Assigned</th>
            <th>Available</th>
            <th>Monthly Price</th>
            <th>Projected Monthly Waste</th>
            <th>Projected Annual Waste</th>
            <th>Evidence</th>
        </tr>
        </thead>
        <tbody>
$unassignedRows
        </tbody>
    </table>
</body>
</html>
"@

    Write-Log "Writing HTML report to $ReportPath"
    Set-Content -Path $ReportPath -Value $html -Encoding UTF8

    Write-Log "HTML report saved to $ReportPath"
}
