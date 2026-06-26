function Get-LicensedUser {
    param (
        [hashtable]$GraphHeaders
    )

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
            $usersResponse = Invoke-GraphGet -Url $usersUrl -Headers $GraphHeaders
        }
        catch {
            $message = "Failed to query licensed users. $($_.Exception.Message)"
            Write-Log $message "ERROR"
            throw $message
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

    return $licensedUsers
}
