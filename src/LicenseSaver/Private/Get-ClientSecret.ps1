function Get-ClientSecret {
    param (
        [string]$SecretEnvVarName
    )

    #read the client secret from the env var for our specific app
    $clientSecret = [Environment]::GetEnvironmentVariable($SecretEnvVarName, "Process")

    if (-not $clientSecret) {
        $message = "Client secret was not found in env var: $SecretEnvVarName"
        Write-Log $message "ERROR"
        throw $message
    }

    Write-Log "client secret found in env var"
    Write-Log "basic config and secret checks passed"

    return $clientSecret
}
