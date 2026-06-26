function Invoke-LicenseSaver {
    param (
        [string]$ConfigPath = ".\Config\config.json",
        [string]$PricePath = ".\Config\sku-prices.json",
        [string]$ReportPath = ".\Output\LicenseReport.html",
        [int[]]$InactiveDays = @(30, 60, 90)
    )

    Write-Log "Starting script"

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

    $disabledLicensedUsers = Get-DisabledLicensedUser -LicensedUsers $licensedUsers

    $inactiveLicensedUsers = Get-InactiveLicensedUser `
        -LicensedUsers $licensedUsers `
        -SkuLookup $skuLookup `
        -InactiveDays $InactiveDays

    Write-Log "$($disabledLicensedUsers.Count) disabled users w/ active licenses found"

    New-LicenseHtmlReport `
        -DisabledUsers $disabledLicensedUsers `
        -InactiveUsers $inactiveLicensedUsers `
        -UnassignedLicenses $unassignedLicenses `
        -ReportPath $ReportPath `
        -SkuLookup $skuLookup `
        -InactiveDays $InactiveDays `
        -TotalMonthlyWasteText $unassignedLicenseResult.TotalMonthlyWasteText `
        -TotalAnnualWasteText $unassignedLicenseResult.TotalAnnualWasteText
}