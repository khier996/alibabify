# this is a temporary place. will need to move it to a worker later

class ProductUpdater

  def update_products(products)
    return unless ItemApiMonitor.safe_to_use?
    products.each do |db_product|
      begin
        @shopify_product =  ShopifyAPI::Product.find(db_product.shopify_product_id)
        db_product.null_not_found
      rescue
        db_product.incr_not_found
        next
      end
      @sku_infos = SkuInfoFetcher.fetch(db_product.taobao_product_id)
      update_product(db_product)
      @shopify_product.save
      sleep(rand(10))
    end
  end

  def update_product(db_product)
    db_product.variants.parsed.each do |db_variant|
      sku_info = @sku_infos[db_variant.sku]
      db_variant.update_info(sku_info, @shopify_product)
    end

    db_product.variants.unparsed.each do |db_variant|
      sku_info = @sku_infos[db_variant.sku]
      db_variant.patch_unparsed_sku(sku_info, @shopify_product)
    end
  end
end

