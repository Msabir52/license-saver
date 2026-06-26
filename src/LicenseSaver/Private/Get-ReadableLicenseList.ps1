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