#logging function so messages have a timestamp.
function Write-Log {
    param (
        [string]$Message,
        [string]$Level = "INFO"
    )

    $timestamp = Get-Date -Format "o"
    $levelUpper = $Level.ToUpperInvariant()
    $line = "$timestamp $levelUpper $Message"

    Write-Host $line

    if ($script:LicenseSaverLogPath) {
        Add-Content -Path $script:LicenseSaverLogPath -Value $line -Encoding UTF8
    }
}
