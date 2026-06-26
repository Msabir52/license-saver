function Get-ExchangeUsageData {
    param (
        [hashtable]$GraphHeaders,

        [ValidateSet("D7", "D30", "D90", "D180")]
        [string]$Period = "D30"
    )

    $url = "https://graph.microsoft.com/v1.0/reports/getEmailActivityUserDetail(period='$Period')"

    Write-Log "Querying Exchange usage for period $Period"

    $exchangeUsage = @(Get-GraphReportCsv `
        -Url $url `
        -Headers $GraphHeaders)

    Write-Log "$($exchangeUsage.Count) Exchange usage rows returned"

    return $exchangeUsage
}
