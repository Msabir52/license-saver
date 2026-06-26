#licensing.ps1

param (
    [string]$ConfigPath = ".\Config\config.json",
    [string]$PricePath = ".\Config\sku-prices.json",
    [string]$ReportPath = ".\Output\LicenseReport.html",
    [int[]]$InactiveDays = @(30, 60, 90)
)

Import-Module .\src\LicenseSaver\LicenseSaver.psd1 -Force

Invoke-LicenseSaver `
    -ConfigPath $ConfigPath `
    -PricePath $PricePath `
    -ReportPath $ReportPath `
    -InactiveDays $InactiveDays