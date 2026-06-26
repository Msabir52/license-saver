function Get-GraphReportCsv {
    param (
        [string]$Url,
        [hashtable]$Headers
    )

    $tempPath = Join-Path $env:TEMP "LicenseSaverReport.csv"

    try {
        # PowerShell follows the Graph 302 response to the CSV download URL.
        Invoke-WebRequest `
            -Uri $Url `
            -Headers $Headers `
            -OutFile $tempPath `
            -MaximumRetryCount 2 `
            -ErrorAction Stop

        return @(Import-Csv -Path $tempPath)
    }
    catch {
        $message = "Failed to download Microsoft Graph report CSV. $($_.Exception.Message)"
        Write-Log $message "ERROR"
        throw $message
    }
    finally {
        Remove-Item $tempPath -ErrorAction SilentlyContinue
    }
}
