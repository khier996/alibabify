class ItemApiMonitor

  @redis = Redis.new(port: 6379, db: 0)

  def self.safe_to_use?
    safe = @redis.get('item_api_safe?')
    if safe.nil?
      @redis.set('item_api_safe?', 'true')
      return true
    end
    return safe == 'true'
  end

  def self.error_products
    @redis.get('item_api_error_product_ids')
  end

  def self.monitor(product_count)
    @unsafe_count = 0
    @product_ids = []
    products = Product.random(product_count)
    products.each { |product| check product }
    if @unsafe_count == 0
      unblock!
    else
      block!(@product_ids)
    end
  end

  private

  def self.check(product)
    sku_infos = SkuInfoFetcher.fetch(product.taobao_product_id)
    if sku_infos.empty?
      @unsafe_count += 1
      @product_ids << product.id
    end
    sleep(rand(20))
  end

  def self.block!(product_ids)
    @redis.set('item_api_safe?', 'false')
    @redis.set('item_api_error_product_ids', product_ids.to_s)
  end

  def self.unblock!
    @redis.set('item_api_safe?', 'true')
    @redis.del('item_api_error_product_ids')
  end
end
