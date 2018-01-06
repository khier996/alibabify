# this is a temporary place. will need to move it to a worker later


def update_products(products)
  products.each do |db_product|
    @db_product = db_product
    @shopify_product =  ShopifyAPI::Product.find(product.id)
    @sku_infos = SkuInfoFetcher.fetch(product.id)
    update_product
  end
end

def update_product
  db_product.variants.parsed.each do |db_variant|
    sku_info = @sku_infos[db_variant.sku]
    db_variant.update_info(sku_info, @shopify_product)
  end

  db_product.variants.unparsed.each do |db_variant|
    sku_info = sku_infos[variant.sku]
    db_variant.patch_unparsed_sku(sku_info)
  end

  @shopify_product.save
end

