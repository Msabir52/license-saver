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
        $message = "Could not read price file: $PricePath. Check that the JSON is valid."
        Write-Log $message "ERROR"
        throw $message
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
