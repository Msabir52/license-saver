Remove-Module LicenseSaver -ErrorAction SilentlyContinue

Import-Module .\src\LicenseSaver\LicenseSaver.psd1 -Force

Invoke-LicenseSaver `
    -ConfigPath .\Config\config.json `
    -PricePath .\Config\sku-prices.json `
    -ReportPath .\Output\LicenseReport.html `
    -LogPath .\Output\LicenseSaver.log `
    -CsvOutputDirectory .\Output `
    -InactiveDays 30,60,90
