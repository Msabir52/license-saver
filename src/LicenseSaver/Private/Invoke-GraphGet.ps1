#429 ERRORS, ETC
#next requirement, handle throttling...
function Invoke-GraphGet {
    param (
        [string]$Url,
        [hashtable]$Headers
    )

    #retry 2 times after throttling 
    $maxRetries = 2
    $retryCount = 0

    #so long as retry count is less than or equal to our max: try again
    while ($retryCount -le $maxRetries) {
        try {
            return Invoke-RestMethod `
                -Method Get `
                -Uri $Url `
                -Headers $Headers `
                -ErrorAction Stop
        }
        #look for error status codes so we can handle the explicit 429 requirement
        catch {
            $statusCode = $_.Exception.Response.StatusCode.value__

            if ($statusCode -eq 429) {
                #looking online at the graph documentation its supposed to tell us after how long to retry
                $retryAfter = $_.Exception.Response.Headers["Retry-After"]
                Write-Log "Graph throttled the request, waiting $retryAfter seconds before retrying." "WARN"
                Start-Sleep -Seconds ([int]$retryAfter)
                $retryCount++
                continue
            }

            #any non-429 error gets shown here
            Write-Log "Graph request failed - status code: $statusCode" "ERROR"
            Write-Log "URL: $Url" "ERROR"
            exit
        }
    }

    #once we reach the limit just say it-
    Write-Log "Graph request failed after $maxRetries retries due to throttling." "ERROR"
    exit
}