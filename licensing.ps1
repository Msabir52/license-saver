#licensing.ps1

param (
    [string]$ConfigPath = ".\Config\config.json"
)



#logging function so messages have a timestamp.
function Write-Log {
    param (
        [string]$Message,
        [string]$Level = "INFO"
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] [$Level] $Message"
}

Write-Log "Starting script."


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
    Write-Log "TenantId is missing from config." "ERROR"
    exit
}
if (-not $clientId) {
    Write-Log "ClientId is missing from config." "ERROR"
    exit
}
if (-not $secretEnvVarName) {
    Write-Log "ClientSecretEnvVar is missing from config." "ERROR"
    exit
}

Write-Log "Config loaded successfully."

#read the client secret from the env var for our specific app
$clientSecret = [Environment]::GetEnvironmentVariable($secretEnvVarName, "Process")
if (-not $clientSecret) {
    Write-Log "Client secret was not found in env var: $secretEnvVarName" "ERROR"
    exit
}
Write-Log "Client secret found in environment variable."
Write-Log "Basic config and secret checks passed."