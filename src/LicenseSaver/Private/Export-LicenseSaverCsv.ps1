function Export-LicenseSaverCsv {
    param (
        [array]$DisabledUsers,
        [array]$InactiveUsers,
        [array]$UnassignedLicenses,
        [string]$CsvOutputDirectory
    )

    function Export-WithColumns {
        param (
            [array]$Rows,
            [string[]]$Columns,
            [string]$Path
        )

        if ($Rows.Count -gt 0) {
            $Rows |
                Select-Object -Property $Columns |
                Export-Csv -Path $Path -NoTypeInformation -Encoding UTF8
        }
        else {
            [PSCustomObject]@{} |
                Select-Object -Property $Columns |
                Export-Csv -Path $Path -NoTypeInformation -Encoding UTF8
        }
    }

    if (-not (Test-Path $CsvOutputDirectory)) {
        New-Item -Path $CsvOutputDirectory -ItemType Directory -Force | Out-Null
    }

    $disabledPath = Join-Path $CsvOutputDirectory "DisabledUsers.csv"
    $inactivePath = Join-Path $CsvOutputDirectory "InactiveUsers.csv"
    $unassignedPath = Join-Path $CsvOutputDirectory "UnassignedLicenses.csv"

    $disabledColumns = @(
        "FindingType",
        "DisplayName",
        "UserPrincipalName",
        "Licenses",
        "LastSignIn",
        "Evidence",
        "Recommendation",
        "MonthlySavings",
        "AnnualSavings",
        "PriceEvidence"
    )

    $inactiveColumns = @(
        "FindingType",
        "ThresholdDays",
        "DisplayName",
        "UserPrincipalName",
        "Licenses",
        "LastSignIn",
        "DaysInactive",
        "Evidence",
        "Recommendation",
        "MonthlySavings",
        "AnnualSavings",
        "PriceEvidence"
    )

    $unassignedColumns = @(
        "SkuPartNumber",
        "TotalEnabled",
        "Assigned",
        "Available",
        "MonthlyPrice",
        "MonthlyWaste",
        "AnnualWaste",
        "Evidence"
    )

    Export-WithColumns -Rows $DisabledUsers -Columns $disabledColumns -Path $disabledPath
    Export-WithColumns -Rows $InactiveUsers -Columns $inactiveColumns -Path $inactivePath
    Export-WithColumns -Rows $UnassignedLicenses -Columns $unassignedColumns -Path $unassignedPath

    Write-Log "CSV export complete. DisabledUsersCsv=$disabledPath InactiveUsersCsv=$inactivePath UnassignedLicensesCsv=$unassignedPath"

    return [PSCustomObject]@{
        DisabledUsersCsv      = $disabledPath
        InactiveUsersCsv      = $inactivePath
        UnassignedLicensesCsv = $unassignedPath
    }
}
