# this is a temporary place. will need to move it to a worker later

class ProductUpdater

  def update_products(products)
    return unless ItemApiMonitor.safe_to_use
    products.each do |db_product|
      @shopify_product =  ShopifyAPI::Product.find(db_product.shopify_product_id)
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

    unless db_product.variants.unparsed.empty?
      headless ||= Headless.new(display: rand(99))
      headless.start
      browser ||= Watir::Browser.new :chrome, :switches => %w[--no-sandbox]

      # browser ||= Watir::Browser.new :chrome # for test on local machine
    end

    db_product.variants.unparsed.each do |db_variant|
      sku_info = @sku_infos[db_variant.sku]
      db_variant.patch_unparsed_sku(sku_info, @shopify_product, browser)
    end

    browser.close if defined? browser
    headless.destroy if defined? headless
  end
end

