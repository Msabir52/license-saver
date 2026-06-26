function Get-UnassignedLicenseFinding {
    param (
        [object]$SubscribedSkus,
        [hashtable]$SkuPriceLookup
    )

    # UNASSIGNED LICENSES
    $unassignedLicenses = @()

    foreach ($sku in $SubscribedSkus.value) {
        $skuPartNumber = $sku.skuPartNumber
        $totalEnabled = $sku.prepaidUnits.enabled
        $assigned = $sku.consumedUnits
        $available = $totalEnabled - $assigned

        $monthlyPrice = $null
        $monthlyWaste = $null
        $annualWaste = $null
        $priceEvidence = "No price found in price file."

        if ($SkuPriceLookup.ContainsKey($skuPartNumber)) {
            $monthlyPrice = $SkuPriceLookup[$skuPartNumber].MonthlyPrice
            $monthlyWaste = $available * $monthlyPrice
            $annualWaste = $monthlyWaste * 12
            $priceEvidence = "Price loaded from configurable SKU price file."
        }

        $monthlySavingsText = "Unknown"
        $annualSavingsText = "Unknown"

        if ($null -ne $monthlyWaste) {
            $monthlySavingsText = '$' + ('{0:N2}' -f $monthlyWaste)
        }

        if ($null -ne $annualWaste) {
            $annualSavingsText = '$' + ('{0:N2}' -f $annualWaste)
        }

        if ($available -gt 0) {
            $unassignedLicense = [PSCustomObject]@{
                SkuPartNumber      = $skuPartNumber
                TotalEnabled       = $totalEnabled
                Assigned           = $assigned
                Available          = $available
                MonthlyPrice       = $monthlyPrice
                MonthlyWaste       = $monthlyWaste
                AnnualWaste        = $annualWaste
                MonthlySavings     = $monthlyWaste
                AnnualSavings      = $annualWaste
                MonthlySavingsText = $monthlySavingsText
                AnnualSavingsText  = $annualSavingsText
                Evidence           = "$available of $totalEnabled enabled seats are not assigned. $priceEvidence"
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

    foreach ($license in $unassignedLicenses) {
        if ($null -ne $license.MonthlyWaste) {
            $totalMonthlyWaste += $license.MonthlyWaste
        }

        if ($null -ne $license.AnnualWaste) {
            $totalAnnualWaste += $license.AnnualWaste
        }
    }

    $totalMonthlyWasteText = '$' + ('{0:N2}' -f $totalMonthlyWaste)
    $totalAnnualWasteText = '$' + ('{0:N2}' -f $totalAnnualWaste)

    Write-Log "$totalUnassignedSeats total unassigned license seats found across $($unassignedLicenses.Count) SKU(s)"
    Write-Log "$totalMonthlyWaste total monthly waste"
    Write-Log "$totalAnnualWaste total annual waste <woah>"

    return [PSCustomObject]@{
        UnassignedLicenses    = $unassignedLicenses
        TotalUnassignedSeats  = $totalUnassignedSeats
        TotalMonthlyWaste     = $totalMonthlyWaste
        TotalAnnualWaste      = $totalAnnualWaste
        TotalMonthlyWasteText = $totalMonthlyWasteText
        TotalAnnualWasteText  = $totalAnnualWasteText
    }
}
