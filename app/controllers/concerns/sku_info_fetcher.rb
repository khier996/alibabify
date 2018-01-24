class SkuInfoFetcher

  @redis = Redis.new(port: 6379, db: 0)

  USER_AGENTS = [
                 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_12_3) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/62.0.3202.94 Safari/537.36',
                 'Mozilla/5.0 (Windows NT 6.1; Win64; x64; rv:47.0) Gecko/20100101 Firefox/47.0',
                 'Mozilla/5.0 (Macintosh; Intel Mac OS X x.y; rv:42.0) Gecko/20100101 Firefox/42.0',
                 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/51.0.2704.103 Safari/537.36',
                 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/51.0.2704.106 Safari/537.36 OPR/38.0.2220.41',
                 'Mozilla/5.0 (iPhone; CPU iPhone OS 10_3_1 like Mac OS X) AppleWebKit/603.1.30 (KHTML, like Gecko) Version/10.0 Mobile/14E304 Safari/602.1',
                 'Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:15.0) Gecko/20100101 Firefox/15.0.1',
                 'Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/47.0.2526.111 Safari/537.36',
                 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_11_2) AppleWebKit/601.3.9 (KHTML, like Gecko) Version/9.0.2 Safari/601.3.9'
                ]

  DEFAULT_REFERER = 'https://detail.tmall.com/item.htm?id=558767486149&cm_id=140105335569ed55e27b&abbucket=0&skuId=3475507336761'


  def self.fetch(product_id) # getting all the prices for a product
    timestamp = Time.now.to_i
    url = "https://mdskip.taobao.com/core/initItemDetail.htm?itemId=#{product_id}&timestamp=#{timestamp}"

    referer = @redis.get('referer_url') || DEFAULT_REFERER

    headers = {'referer' => referer,
               'user-agent' => USER_AGENTS.sample}

    response = HTTParty.get(url, headers: headers)

    prices = response.parsed_response['defaultModel']['itemPriceResultDO']['priceInfo']
    @quantities = response.parsed_response['defaultModel']['inventoryDO']['skuQuantity']

    sku_infos = {}
    prices.each do |sku, price|
      if price['promotionList']
        sku_infos[sku] = read_promotion_list(sku, price)
      elsif price['suggestivePromotionList']
        sku_infos[sku] = read_suggestive_promotion_list(sku, price)
      end
    end
    return sku_infos
  end

  def self.read_promotion_list(sku, price)
    promo_price = price['promotionList'].first['price']
    original_price = price['price']
    quantity = @quantities[sku]['quantity']
    return {'promo_price' => promo_price,
            'original_price' => original_price,
            'quantity' => quantity}
  end

  def self.read_suggestitve_promotion_list(sku, price)
    promo_price = price['suggestivePromotionList'][0]['price'].to_f
    original_price = price['price'].to_f
    quantity = @quantities[sku]['quantity']

    return {'promo_price' => promo_price,
            'original_price' => original_price,
            'quantity' => quantity}
  end
end

