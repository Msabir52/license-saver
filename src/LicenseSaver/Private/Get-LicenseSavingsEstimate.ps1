function Get-LicenseSavingsEstimate {
    param (
        [array]$AssignedLicenses,
        [hashtable]$SkuLookup,
        [hashtable]$SkuPriceLookup
    )

    $licenseNames = @()
    $missingPrices = @()
    $monthlySavings = [decimal]0

    foreach ($license in $AssignedLicenses) {
        $skuId = $license.skuId
        $skuPartNumber = $skuId

        if ($SkuLookup.ContainsKey($skuId)) {
            $skuPartNumber = $SkuLookup[$skuId]
        }

        $licenseNames += $skuPartNumber

        if ($SkuPriceLookup.ContainsKey($skuPartNumber)) {
            $monthlySavings += [decimal]$SkuPriceLookup[$skuPartNumber].MonthlyPrice
        }
        else {
            $missingPrices += $skuPartNumber
        }
    }

    $annualSavings = $monthlySavings * 12
    $priceEvidence = "Prices loaded from configurable SKU price file."

    if ($missingPrices.Count -gt 0) {
        $priceEvidence = "No price found for SKU(s): $($missingPrices -join ', '). Savings total only includes priced SKU(s)."
    }

    return [PSCustomObject]@{
        LicenseList        = ($licenseNames -join ", ")
        MonthlySavings     = $monthlySavings
        AnnualSavings      = $annualSavings
        MonthlySavingsText = '$' + ('{0:N2}' -f $monthlySavings)
        AnnualSavingsText  = '$' + ('{0:N2}' -f $annualSavings)
        PriceEvidence      = $priceEvidence
    }
}
