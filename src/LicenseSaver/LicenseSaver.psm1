# LicenseSaver.psm1

# Load private functions first.
$privateFunctions = Get-ChildItem -Path "$PSScriptRoot\Private\*.ps1"

foreach ($function in $privateFunctions) {
    . $function.FullName
}

# Load public functions.
$publicFunctions = Get-ChildItem -Path "$PSScriptRoot\Public\*.ps1"

foreach ($function in $publicFunctions) {
    . $function.FullName
}

# Only expose the main command.
Export-ModuleMember -Function Invoke-LicenseSaver