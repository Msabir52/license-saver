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

Write-Log "Starting script"

#HELPER FUNCTIONS

#429 ERRORS, ETC
#next requirement, handle throttling...
function Invoke-GraphGet {
    param ([string]$Url,[hashtable]$Headers)

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
                Write-Log "Graph throttledthe request, waiting $retryAfter seconds before retrying." "WARN"
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

#GRAPH REPORTS
function Get-GraphReportCsv {
    param ([string]$Url, [hashtable]$Headers)

    Write-Log "Requesting report CSV from Graph"
    #adding to just try and get the csv
    try {
        $response = Invoke-WebRequest `
            -Method Get `
            -Uri $Url `
            -Headers $Headers `
            -MaximumRedirection 0 `
            -ErrorAction Stop
    }


    catch {
        #302s are okay, we just need the location header extracted
   
        $statusCode = $_.Exception.Response.StatusCode.value__
        
        if ($statusCode -eq 302) {
            #grab the temporary CSV download URL from the Location header
            Write-Log "302d"
            $downloadUrl = $_.Exception.Response.Headers["Location"]

            if (-not $downloadURL){
                Write-Log "302 did not include location header" "ERROR"
                exit
            }
            Write-Log "Downloading CSV."

            try{
            $csvText = Invoke-RestMethod `
                -Method Get `
                -Uri $downloadUrl `
                -ErrorAction Stop

            #convert the CSV text into PowerShell objects.
            return $csvText | ConvertFrom-Csv
            }
            catch {
                Write-Log "failed to dl csv"
                Write-Log "error message: $($_.Exception.Message)" "ERROR" 
                exit
            }
        }
        

        Write-Log "Report request failed. Status code: $statusCode" "ERROR"
        #was getting 404d, adding another write line
        Write-Log "Report URL: $Url"
        exit
    }

    #if we got this far we did something wrong
    Write-Log "Report request did not return CSV content." "ERROR"
    exit
}

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

#read the client secret from the env var for our specific app
$clientSecret = [Environment]::GetEnvironmentVariable($secretEnvVarName, "Process")
if (-not $clientSecret) {
    Write-Log "Client secret was not found in env var: $secretEnvVarName" "ERROR"
    exit
}
Write-Log "client secret found in env var"
Write-Log "basic config and secret checks passed"


#part 2 - grabbing the user info
#grab the base URL for requests, and build the message with the client secret
$tokenUrl = "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token"
$tokenBody = @{
    client_id     = $clientId
    client_secret = $clientSecret
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
    Write-Log "auth failed. Check data and app permissions." "ERROR"
    exit
}

$graphHeaders = @{Authorization = "Bearer $accessToken"}
Write-Log "Graph Header ready"


#now query the information

#empty array to hold the licensed user info
$licensedUsers = @()

#use a page size of 500, and pass assignedLicenses ensuring we get all the other relevant info
$usersUrl = "https://graph.microsoft.com/v1.0/users?`$select=id,displayName,userPrincipalName,accountEnabled,assignedLicenses,signInActivity&`$top=500"
Write-Log "Querying users"

#while loop to go through all the users in the array
while ($usersUrl) {
    try {
        #first page
        #$usersResponse = Invoke-RestMethod `
        #    -Method Get `
        #    -Uri $usersUrl `
        #    -Headers $graphHeaders
        
        #updated to call Invoke-GraphGet for the error handling, using helper function
        $usersResponse = Invoke-GraphGet -Url $usersUrl -Headers $graphHeaders
    }
    catch {
        Write-Log "Failed to query" "ERROR"
        exit
    }

    #go through each user returned on this page
    foreach ($user in $usersResponse.value) {
        #assignedLicenses is an array - grab all that are greater than 0 and add to array
        if ($user.assignedLicenses.Count -gt 0) {
            $licensedUsers += $user
        }
    }


    #page over to the next
    $usersUrl = $usersResponse.'@odata.nextLink'
}

Write-Log "Finished querying"
Write-Log "$($licensedUsers.Count) Licensed users found in tenant "

#using 30 days as the baseline
$activeUserReportUrl = "https://graph.microsoft.com/v1.0/reports/getOffice365ActiveUserDetail(period='D30')"

Write-Log "Pulling 90d active user detail report"

$activeUserReport = Get-GraphReportCsv `
    -Url $activeUserReportUrl `
    -Headers $graphHeaders

Write-Log "Rows found: $($activeUserReport.Count)"
Write-Log "Office 365 active user detail report columns:"

$activeUserReport |
    Select-Object -First 1 |
    Format-List