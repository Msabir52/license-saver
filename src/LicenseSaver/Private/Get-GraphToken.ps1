function Get-GraphToken {
    param (
        [string]$TenantId,
        [string]$ClientId,
        [string]$ClientSecret
    )

    #part 2 - grabbing the user info
    #grab the base URL for requests, and build the message with the client secret
    $tokenUrl = "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token"

    $tokenBody = @{
        client_id     = $ClientId
        client_secret = $ClientSecret
        scope         = "https://graph.microsoft.com/.default"
        grant_type    = "client_credentials"
    }

    #ask for a graph access token
    try {
        $tokenResponse = Invoke-RestMethod `
            -Method Post `
            -Uri $tokenUrl `
            -Body $tokenBody `
            -ContentType "application/x-www-form-urlencoded"

        $accessToken = $tokenResponse.access_token

        Write-Log "Access token received"
    }
    #failure print
    catch {
        $message = "Authentication failed. Check TenantId, ClientId, client secret, and admin consent for Graph application permissions."
        Write-Log $message "ERROR"
        throw $message
    }

    return $accessToken
}
