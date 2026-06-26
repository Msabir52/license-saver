function Get-SubscribedSkuData {
    param (
        [hashtable]$GraphHeaders
    )

    #addition: readable name licenses

    #grab all the skus data from graph
    $subscribedSkusUrl = "https://graph.microsoft.com/v1.0/subscribedSkus"

    $subscribedSkus = Invoke-GraphGet `
        -Url $subscribedSkusUrl `
        -Headers $GraphHeaders

    #lookup table wohoo
    $skuLookup = @{}

    foreach ($sku in $subscribedSkus.value) {
        $skuLookup[$sku.skuId] = $sku.skuPartNumber
    }

    return [PSCustomObject]@{
        SubscribedSkus = $subscribedSkus
        SkuLookup      = $skuLookup
    }
}