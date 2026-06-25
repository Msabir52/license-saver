#licensing.ps1

param (
    [string]$ConfigPath = ".\Config\config.json",
    [string]$PricePath = ".\Config\sku-prices.json",
    [string]$ReportPath = ".\Output\LicenseReport.html",
    [int[]]$InactiveDays = @(30, 60, 90)



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


#LICENSE HELPER FUNCTION (since its gonna be needed multiple times now...)
function Get-ReadableLicenseList {
    param (
        [array]$AssignedLicenses,
        [hashtable]$SkuLookup
    )
    $licenseNames = @()
    foreach ($license in $AssignedLicenses) {
        $skuId = $license.skuId

        if ($SkuLookup.ContainsKey($skuId)) {
            $licenseNames += $SkuLookup[$skuId]
        }
        else {
            $licenseNames += $skuId
        }
    }

    return ($licenseNames -join ", ")
}

#CONFIGURABLE SKU PRICING LOOKUP
function Get-SkuPriceLookup {
    param (
        [string]$PricePath
    )

    $priceLookup = @{}

    if (-not (Test-Path $PricePath)) {
        Write-Log "Price file not found: $PricePath" "WARN"
        Write-Log "Savings calculations will show as unknown." "WARN"
        return $priceLookup
    }

    try {
        $priceConfig = Get-Content $PricePath -Raw | ConvertFrom-Json
    }
    catch {
        Write-Log "Could not read price file: $PricePath" "ERROR"
        Write-Log "Check that the JSON is valid." "ERROR"
        exit
    }

    foreach ($property in $priceConfig.PSObject.Properties) {
        $skuPartNumber = $property.Name
        $priceInfo = $property.Value

        $priceLookup[$skuPartNumber] = [PSCustomObject]@{
            DisplayName  = $priceInfo.DisplayName
            MonthlyPrice = [decimal]$priceInfo.MonthlyPrice
        }
    }

    Write-Log "$($priceLookup.Count) SKU prices loaded from $PricePath"

    return $priceLookup
}

#REPORT FUNCTION 
function LicenseHtmlReport {

    param (
        [array]$DisabledUsers,
        [array]$InactiveUsers,
        [array]$UnassignedLicenses,
        [string]$ReportPath,
        [hashtable]$SkuLookup,
        [int[]]$InactiveDays
    )

    Write-Log "Building report"

    # DISABLED USERS TABLE ROWS
    $disabledRows = ""

    foreach ($user in $DisabledUsers) {

        $licenseList = Get-ReadableLicenseList `
            -AssignedLicenses $user.assignedLicenses `
            -SkuLookup $SkuLookup

        $lastSignIn = $user.signInActivity.lastSignInDateTime

        if (-not $lastSignIn) {
            $lastSignIn = "No sign-in data returned"
        }

        $disabledRows += @"
        <tr>
            <td>$($user.displayName)</td>
            <td>$($user.userPrincipalName)</td>
            <td>$licenseList</td>
            <td>$lastSignIn</td>
            <td>Account is disabled but still has an assigned license.</td>
            <td>Review and consider reclaiming license.</td>
        </tr>
"@
    }

    if ($DisabledUsers.Count -eq 0) {
        $disabledRows = @"
        <tr>
            <td colspan="6">No disabled users with active licenses were found.</td>
        </tr>
"@
    }

    # INACTIVE USERS TABLE ROWS
    $inactiveRows = ""

    foreach ($user in $InactiveUsers) {

        $inactiveRows += @"
        <tr>
            <td>$($user.ThresholdDays)+ days</td>
            <td>$($user.DisplayName)</td>
            <td>$($user.UserPrincipalName)</td>
            <td>$($user.Licenses)</td>
            <td>$($user.LastSignIn)</td>
            <td>$($user.DaysInactive)</td>
            <td>$($user.Evidence)</td>
            <td>$($user.Recommendation)</td>
        </tr>
"@
    }

    #ideal case :)
    if ($InactiveUsers.Count -eq 0) {
        $inactiveRows = @"
        <tr>
        <td colspan="8">No active licensed users inactive for these thresholds were found: $($InactiveDays -join ', ') days.</td>        </tr>
"@
    }

    # UNASSIGNED LICENSE TABLE ROWS
$unassignedRows = ""

foreach ($license in $UnassignedLicenses) {

    $monthlyPrice = "Unknown"
    $monthlyWaste = "Unknown"
    $annualWaste = "Unknown"

    if ($null -ne $license.MonthlyPrice) {
        $monthlyPrice = '$' + $license.MonthlyPrice
    }

    if ($null -ne $license.MonthlyWaste) {
        $monthlyWaste = '$' + $license.MonthlyWaste
    }

    if ($null -ne $license.AnnualWaste) {
        $annualWaste = '$' + $license.AnnualWaste
    }

    $unassignedRows += @"
        <tr>
            <td>$($license.SkuPartNumber)</td>
            <td>$($license.TotalEnabled)</td>
            <td>$($license.Assigned)</td>
            <td>$($license.Available)</td>
            <td>$monthlyPrice</td>
            <td>$monthlyWaste</td>
            <td>$annualWaste</td>
            <td>$($license.Evidence)</td>
        </tr>
"@
}

if ($UnassignedLicenses.Count -eq 0) {
    $unassignedRows = @"
        <tr>
            <td colspan="8">No unassigned licenses were found.</td>
        </tr>
"@
}

$totalUnassignedSeats = 0

foreach ($license in $UnassignedLicenses) {
    $totalUnassignedSeats += $license.Available
}

    $html = @"
<!doctype html>
<html>
<head>
    <meta charset="utf-8">
    <title>Microsoft 365 License Report</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            margin: 30px;
        }

        h1 {
            margin-bottom: 5px;
        }

        .summary {
            margin: 15px 0;
            font-size: 18px;
            font-weight: bold;
        }

        .summary-box {
            border: 1px solid #cccccc;
            background-color: #f7f7f7;
            padding: 12px;
            margin-bottom: 25px;
        }

        table {
            border-collapse: collapse;
            width: 100%;
            margin-bottom: 30px;
        }

        th, td {
            border: 1px solid #cccccc;
            padding: 8px;
            text-align: left;
            vertical-align: top;
        }

        th {
            background-color: #eeeeee;
        }

        tr:nth-child(even) {
            background-color: #f7f7f7;
        }

        .note {
            margin-top: 20px;
            font-size: 13px;
        }
    </style>
</head>
<body>
    <h1>Microsoft 365 License Report</h1>

    <div class="summary-box">
        <div class="summary">$($DisabledUsers.Count) disabled users with active licenses found.</div>
        <div class="summary">$($InactiveUsers.Count) inactive-user findings across thresholds: $($InactiveDays -join ', ') days.</div>
        <div class="summary">$totalUnassignedSeats unassigned license seats found across $($UnassignedLicenses.Count) SKU(s).</div>   </div>
        <div class="summary">Projected unassigned-license waste: $totalMonthlyWasteText monthly / $totalAnnualWasteText annually.</div>
    </div>

    <h2>Disabled Users With Active Licenses</h2>

    <table>
        <thead>
            <tr>
                <th>Name</th>
                <th>UPN</th>
                <th>Licenses</th>
                <th>Last Sign-In</th>
                <th>Evidence</th>
                <th>Recommendation</th>
            </tr>
        </thead>
        <tbody>
$disabledRows
        </tbody>
    </table>

    <h2>Inactive Licensed Users</h2>

    <table>
        <thead>
            <tr>
                <th>Threshold</th>
                <th>Name</th>
                <th>UPN</th>
                <th>Licenses</th>
                <th>Last Sign-In</th>
                <th>Days Inactive</th>
                <th>Evidence</th>
                <th>Recommendation</th>
            </tr>
        </thead>
        <tbody>
$inactiveRows
        </tbody>
    </table>

    <div class="note">
        <strong>Methodology:</strong>
        Disabled licensed users are users where accountEnabled is false and assignedLicenses has one or more entries.
        Inactive licensed users are enabled licensed users where the last sign-in date is older than $InactiveDays days.
        Users with no sign-in data returned by Microsoft Graph are included for manual review.
    </div>

    <h2>Unassigned Licenses</h2>

    <table>
        <thead>
        <tr>
            <th>Sku Part Number</th>
            <th>Total Enabled</th>
            <th>Assigned</th>
            <th>Available</th>
            <th>Monthly Price</th>
            <th>Projected Monthly Waste</th>
            <th>Projected Annual Waste</th>
            <th>Evidence</th>
        </tr>
        </thead>
        <tbody>
$unassignedRows
        </tbody>
    </table>
</body>
</html>
"@

    Set-Content -Path $ReportPath -Value $html -Encoding UTF8

    Write-Log "HTML report saved to $ReportPath"
}

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

$skuPriceLookup = Get-SkuPriceLookup -PricePath $PricePath

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

#addition: readable name licenses

#grab all the skus data from graph
$subscribedSkusUrl = "https://graph.microsoft.com/v1.0/subscribedSkus"
$subscribedSkus = Invoke-GraphGet `
    -Url $subscribedSkusUrl `
    -Headers $graphHeaders

#lookup table wohoo
$skuLookup = @{}
foreach ($sku in $subscribedSkus.value) {
    $skuLookup[$sku.skuId] = $sku.skuPartNumber
}

# UNASSIGNED LICENSES
$unassignedLicenses = @()

foreach ($sku in $subscribedSkus.value) {
    $skuPartNumber = $sku.skuPartNumber
    $totalEnabled = $sku.prepaidUnits.enabled
    $assigned = $sku.consumedUnits
    $available = $totalEnabled - $assigned

    $monthlyPrice = $null
    $monthlyWaste = $null
    $annualWaste = $null
    $priceEvidence = "No price found in price file."

    if ($skuPriceLookup.ContainsKey($skuPartNumber)) {
        $monthlyPrice = $skuPriceLookup[$skuPartNumber].MonthlyPrice
        $monthlyWaste = $available * $monthlyPrice
        $annualWaste = $monthlyWaste * 12
        $priceEvidence = "Price loaded from configurable SKU price file."
    }

    if ($available -gt 0) {
        $unassignedLicense = [PSCustomObject]@{
            SkuPartNumber = $skuPartNumber
            TotalEnabled  = $totalEnabled
            Assigned      = $assigned
            Available     = $available
            MonthlyPrice  = $monthlyPrice
            MonthlyWaste  = $monthlyWaste
            AnnualWaste   = $annualWaste
            Evidence      = "$available of $totalEnabled enabled seats are not assigned. $priceEvidence"
        }

        $unassignedLicenses += $unassignedLicense
    }
}

$totalUnassignedSeats = 0

foreach ($license in $unassignedLicenses) {
    $totalUnassignedSeats += $license.Available
}

$totalMonthlyWaste = 0
$totalAnnualWaste = 0

foreach ($license in $UnassignedLicenses) {
    if ($null -ne $license.MonthlyWaste) {
        $totalMonthlyWaste += $license.MonthlyWaste
    }

    if ($null -ne $license.AnnualWaste) {
        $totalAnnualWaste += $license.AnnualWaste
    }
}

$totalMonthlyWasteText = '$' + $totalMonthlyWaste
$totalAnnualWasteText = '$' + $totalAnnualWaste


Write-Log "$totalUnassignedSeats total unassigned license seats found across $($unassignedLicenses.Count) SKU(s)"
Write-Log "$totalMonthlyWaste total monthly waste"
Write-Log "$totalAnnualWaste total annual waste"

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
<#
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
#>

#TRUCKING ALONG WITH THE FIRST CORE REQUIREMENT - UNLICENSING DISABLED ACCOUNTS

$disabledLicensedUsers = @()
foreach ($user in $licensedUsers) {
    if ($user.accountEnabled -eq $false) {
        $disabledLicensedUsers += $user
    }
}

# CORE REQUIREMENT 2 (#5 in readme tho) - ACTIVE LICENSED USERS WITH NO SIGN-IN IN X DAYS

$inactiveLicensedUsers = @()
#no longer only passing one number and now its an array so this is unneeded and doesnt work
#$inactiveCutoffDate = (Get-Date).AddDays(-$InactiveDays)

# Sort thresholds from biggest to smallest.
# This lets us label a 100-day inactive user as 90+ instead of 30+.
$sortedInactiveDays = $InactiveDays | Sort-Object -Descending

Write-Log "Checking inactive users for thresholds: $($InactiveDays -join ', ') days"

        foreach ($user in $licensedUsers) {
            #skip disabled users
            if ($user.accountEnabled -eq $false) {
                continue
            }

            $lastSignInRaw = $user.signInActivity.lastSignInDateTime
            $licenseList = Get-ReadableLicenseList `
                -AssignedLicenses $user.assignedLicenses `
                -SkuLookup $skuLookup

            if (-not $lastSignInRaw) {
                $inactiveUser = [PSCustomObject]@{
                    ThresholdDays     = $days
                    DisplayName       = $user.displayName
                    UserPrincipalName = $user.userPrincipalName
                    Licenses          = $licenseList
                    LastSignIn        = "No sign-in data returned"
                    DaysInactive      = "Unknown"
                    Evidence          = "Microsoft Graph did not return a last sign-in date."
                    Recommendation    = "Review account manually and consider reclaiming license if unused."
                }

                $inactiveLicensedUsers += $inactiveUser
                continue
            }


            $lastSignInDate = [datetime]$lastSignInRaw
            $daysInactive = ((Get-Date) - $lastSignInDate).Days

            $matchedThreshold = $null

        foreach ($days in $sortedInactiveDays) {
            if ($daysInactive -ge $days) {
                $matchedThreshold = $days
                break
            }
        }

        if ($matchedThreshold) {

            $inactiveUser = [PSCustomObject]@{
                ThresholdDays     = $matchedThreshold
                DisplayName       = $user.displayName
                UserPrincipalName = $user.userPrincipalName
                Licenses          = $licenseList
                LastSignIn        = $lastSignInDate
                DaysInactive      = $daysInactive
                Evidence          = "Last sign-in was $daysInactive days ago."
                Recommendation    = "Review account manually and consider reclaiming license if unused."
            }

            $inactiveLicensedUsers += $inactiveUser
        }
    }


Write-Log "$($inactiveLicensedUsers.Count) inactive licensed users found across thresholds: $($InactiveDays -join ', ') days"
Write-Log "$($disabledLicensedUsers.Count) disabled users w/ active licenses found"
LicenseHtmlReport `
    -DisabledUsers $disabledLicensedUsers `
    -InactiveUsers $inactiveLicensedUsers `
    -UnassignedLicenses $unassignedLicenses `
    -ReportPath $ReportPath `
    -SkuLookup $skuLookup `
    -InactiveDays $InactiveDays
