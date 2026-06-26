function Invoke-LicenseSaver {
    param (
        [string]$ConfigPath = ".\Config\config.json",
        [string]$PricePath = ".\Config\sku-prices.json",
        [string]$ReportPath = ".\Output\LicenseReport.html",
        [string]$LogPath = ".\Output\LicenseSaver.log",
        [string]$CsvOutputDirectory = ".\Output",
        [int[]]$InactiveDays = @(30, 60, 90)
    )

    $script:LicenseSaverLogPath = $LogPath

    $logDirectory = Split-Path -Path $LogPath -Parent

    if ($logDirectory -and -not (Test-Path $logDirectory)) {
        New-Item -Path $logDirectory -ItemType Directory -Force | Out-Null
    }

    "Run started: $(Get-Date -Format o)" | Set-Content -Path $LogPath -Encoding UTF8

    Write-Log "Starting License Saver"
    Write-Log "ConfigPath=$ConfigPath"
    Write-Log "PricePath=$PricePath"
    Write-Log "ReportPath=$ReportPath"
    Write-Log "LogPath=$LogPath"
    Write-Log "CsvOutputDirectory=$CsvOutputDirectory"
    Write-Log "InactiveDays=$($InactiveDays -join ',')"

    $config = Get-LicenseSaverConfig -ConfigPath $ConfigPath

    $skuPriceLookup = Get-SkuPriceLookup -PricePath $PricePath

    $clientSecret = Get-ClientSecret -SecretEnvVarName $config.ClientSecretEnvVar

    $accessToken = Get-GraphToken `
        -TenantId $config.TenantId `
        -ClientId $config.ClientId `
        -ClientSecret $clientSecret

    $graphHeaders = @{Authorization = "Bearer $accessToken"}

    Write-Log "Graph Header ready"

    $subscribedSkuData = Get-SubscribedSkuData -GraphHeaders $graphHeaders

    $subscribedSkus = $subscribedSkuData.SubscribedSkus
    $skuLookup = $subscribedSkuData.SkuLookup

    $unassignedLicenseResult = Get-UnassignedLicenseFinding `
        -SubscribedSkus $subscribedSkus `
        -SkuPriceLookup $skuPriceLookup

    $unassignedLicenses = $unassignedLicenseResult.UnassignedLicenses

    $licensedUsers = Get-LicensedUser -GraphHeaders $graphHeaders

    try {
        $exchangeUsage = @(Get-ExchangeUsageData `
            -GraphHeaders $graphHeaders `
            -Period "D30")
    }
    catch {
        $message = "Exchange usage report unavailable. Continuing without Exchange usage data. $($_.Exception.Message)"
        Write-Log $message "WARN"
        $exchangeUsage = @()
    }

    $disabledLicensedUsers = Get-DisabledLicensedUser `
        -LicensedUsers $licensedUsers `
        -SkuLookup $skuLookup `
        -SkuPriceLookup $skuPriceLookup

    $inactiveLicensedUsers = Get-InactiveLicensedUser `
        -LicensedUsers $licensedUsers `
        -SkuLookup $skuLookup `
        -SkuPriceLookup $skuPriceLookup `
        -InactiveDays $InactiveDays

    Write-Log "$($disabledLicensedUsers.Count) disabled users w/ active licenses found"

    $disabledMonthlySavings = ($disabledLicensedUsers | Measure-Object -Property MonthlySavings -Sum).Sum
    $inactiveMonthlySavings = ($inactiveLicensedUsers | Measure-Object -Property MonthlySavings -Sum).Sum

    if ($null -eq $disabledMonthlySavings) {
        $disabledMonthlySavings = 0
    }

    if ($null -eq $inactiveMonthlySavings) {
        $inactiveMonthlySavings = 0
    }

    $totalMonthlySavings = [decimal]$disabledMonthlySavings + [decimal]$inactiveMonthlySavings + [decimal]$unassignedLicenseResult.TotalMonthlyWaste
    $totalAnnualSavings = $totalMonthlySavings * 12

    $totalMonthlySavingsText = '$' + ('{0:N2}' -f $totalMonthlySavings)
    $totalAnnualSavingsText = '$' + ('{0:N2}' -f $totalAnnualSavings)

    Write-Log "Total projected savings calculated. Monthly=$totalMonthlySavingsText Annual=$totalAnnualSavingsText"

    New-LicenseHtmlReport `
        -DisabledUsers $disabledLicensedUsers `
        -InactiveUsers $inactiveLicensedUsers `
        -UnassignedLicenses $unassignedLicenses `
        -ExchangeUsage $exchangeUsage `
        -ReportPath $ReportPath `
        -SkuLookup $skuLookup `
        -InactiveDays $InactiveDays `
        -TotalMonthlyWasteText $unassignedLicenseResult.TotalMonthlyWasteText `
        -TotalAnnualWasteText $unassignedLicenseResult.TotalAnnualWasteText `
        -TotalMonthlySavingsText $totalMonthlySavingsText `
        -TotalAnnualSavingsText $totalAnnualSavingsText

    Export-LicenseSaverCsv `
        -DisabledUsers $disabledLicensedUsers `
        -InactiveUsers $inactiveLicensedUsers `
        -UnassignedLicenses $unassignedLicenses `
        -CsvOutputDirectory $CsvOutputDirectory
}
