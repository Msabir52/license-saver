function Get-LicenseSaverConfig {
    param (
        [string]$ConfigPath
    )

    #check that the config file exists before trying to read it
    if (-not (Test-Path $ConfigPath)) {
        $message = "Config file not found: $ConfigPath"
        Write-Log $message "ERROR"
        throw $message
    }

    #read the config file and convert the JSON into a ps obj, pull the values and store them as such here
    $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
    $tenantId = $config.TenantId
    $clientId = $config.ClientId
    $secretEnvVarName = $config.ClientSecretEnvVar

    #edge cases should any bit of info be missing from the config.json grab
    if (-not $tenantId) {
        $message = "TenantId is missing from config file: $ConfigPath"
        Write-Log $message "ERROR"
        throw $message
    }

    if (-not $clientId) {
        $message = "ClientId is missing from config file: $ConfigPath"
        Write-Log $message "ERROR"
        throw $message
    }

    if (-not $secretEnvVarName) {
        $message = "ClientSecretEnvVar is missing from config file: $ConfigPath"
        Write-Log $message "ERROR"
        throw $message
    }

    Write-Log "Config loaded"

    return [PSCustomObject]@{
        TenantId           = $tenantId
        ClientId           = $clientId
        ClientSecretEnvVar = $secretEnvVarName
    }
}
