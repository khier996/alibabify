class SkuPriceFetcher

  def self.fetch(product_id) # getting all the prices for a product
    timestamp = Time.now.to_i
    url = "https://mdskip.taobao.com/core/initItemDetail.htm?itemId=#{product_id}&timestamp=#{timestamp}"

    headers = {'referer' => 'https://detail.tmall.com/item.htm?id=558767486149&cm_id=140105335569ed55e27b&abbucket=0&skuId=3475507336761',
               'user-agent' => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_12_3) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/62.0.3202.94 Safari/537.36'}
    response = HTTParty.get(url, headers: headers)
    prices = response.parsed_response['defaultModel']['itemPriceResultDO']['priceInfo']

    sku_prices = {}
    prices.each do |sku, price|
      next unless price['promotionList']
      promo_price = price['promotionList'][0]['price'].to_f
      original_price = price['price'].to_f
      sku_prices[sku] = {'promo_price' => promo_price, 'original_price' => original_price}
    end
    return sku_prices
  end
end

