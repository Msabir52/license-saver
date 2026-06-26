function Get-LicenseSaverConfig {
    param (
        [string]$ConfigPath
    )

    #check that the config file exists before trying to read it
    if (-not (Test-Path $ConfigPath)) {
        Write-Log "Config file not found: $ConfigPath" "ERROR"
        exit
    }

    #read the config file and convert the JSON into a ps obj, pull the values and store them as such here
    $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
    $tenantId = $config.TenantId
    $clientId = $config.ClientId
    $secretEnvVarName = $config.ClientSecretEnvVar

    #edge cases should any bit of info be missing from the config.json grab
    if (-not $tenantId) {
        Write-Log "TenantId is missing" "ERROR"
        exit
    }

    if (-not $clientId) {
        Write-Log "ClientId is missing" "ERROR"
        exit
    }

    if (-not $secretEnvVarName) {
        Write-Log "ClientSecretEnvVar is missing" "ERROR"
        exit
    }

    Write-Log "Config loaded"

    return [PSCustomObject]@{
        TenantId           = $tenantId
        ClientId           = $clientId
        ClientSecretEnvVar = $secretEnvVarName
    }
}