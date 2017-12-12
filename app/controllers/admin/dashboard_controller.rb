class Admin::DashboardController < ShopifyApp::AuthenticatedController
  require 'watir'
  require 'nokogiri'
  require 'open-uri'

  def index
    @products = ShopifyAPI::Product.find(:all, :params => {:limit => 10})

    product_attrs = {
      "title": "Burton Custom Freestyle 151",
      "body_html": "<strong>Good snowboard!<\/strong>",
      "vendor": "Burton",
      "product_type": "Snowboard",
      "options": [{"name": 'color'}, {"name": 'size'}],
      "variants": [],
      "images": [
        {'src': 'https://arcservices.org/content/uploads/sites/23/2017/02/catalog_detail_image_large.jpg'},
        {'src': 'https://rukminim1.flixcart.com/image/704/704/j1wgjgw0/t-shirt/g/m/u/xxl-ts900805-ghpc-original-imaeqyhsfq6zweum.jpeg?q=70'}
      ]
    }
    product = ShopifyAPI::Product.new
    # product.attributes = product_attrs
    product.attributes = get_product_attrs
    product.save
    byebug
    @browser.close
  end

  def kurut
  end

  private

  def test_variant
    return {:compare_at_price=>169.0, :fulfillment_service=>"manual", :inventory_management=>"shopify", :inventory_policy=>"continue", :inventory_quantity=>10, :price=>nil, :product_id=>"535772624331", :requires_shipping=>true, :sku=>"3195851195064", :title=>"pink", "option0"=>"黑色176011172", "option1"=>"44"}
  end

  def get_product_attrs
    url = 'https://detail.tmall.com/item.htm?spm=a230r.1.14.6.3e2e4a3dh91FYr&id=535772624331&cm_id=140105335569ed55e27b&abbucket=20'
    @browser = Watir::Browser.new :chrome
    @browser.goto(url)
    @browser.wait(5)

    props = @browser.dls(css: '.tb-prop')
    props = filter_props(props)
    @variants = []
    @prop_imgs = {}
    @images = []
    find_variants(props, props.count - 1, {'props' => {}})
    find_images
    return reformat_data
  end

  def find_images
    @browser.execute_script('window.scrollBy(0, 1000)')
    sleep(1)
    doc = Nokogiri::HTML(@browser.html)
    @title = doc.css('.tb-detail-hd h1').text.gsub(/\t|\n/, '')
    images = doc.css('#description img')
    images.each do |image|
      lazyload = image.attributes['data-ks-lazyload']
      src = lazyload ? lazyload.value : image.attributes['src'].value
      @images << src
    end
  end

  def filter_props(props)
    props = props.select do |prop|
      prop_doc = Nokogiri::HTML(prop.html)
      classes = prop_doc.css('.tb-prop').attribute('class').value.split(' ')
      (classes & %w(tb-hidden J_tmSaleTime)).empty?
    end
  end

  def find_variants(props, level, prop_hash)
    prop_name = props[level].dts.first.text
    variants = props[level].lis
    variants = choose_variants(variants)
    variants.each do |variant|
      variant_name = variant.text.gsub(/\n已选中/, '')
      variant.as.first.click
      if level == 0
        prop_hash['props'] = prop_hash['props'].clone
        prop_hash['props'][prop_name] = variant_name
        prop_hash = update_prop_hash_with_ids(prop_hash)
        prop_hash = update_prop_hash_with_image(prop_hash, variant_name, variant)
        prop_hash = update_prop_hash_with_prices(prop_hash)
        @variants << prop_hash.clone
        next
      else
        prop_hash['props'] = prop_hash['props'].clone
        prop_hash['props'][prop_name] = variant_name
        find_variants(props, level-1, prop_hash)
      end
    end
  end

  def choose_variants(variants)
    variants = variants.reject do |variant|
      doc = Nokogiri::HTML(variant.html)
      variant_class = doc.css('li').first.attributes['class']
      variant_class && variant_class.value == 'tb-out-of-stock'
    end
    variants
  end

  def update_prop_hash_with_ids(prop_hash)
    params = CGI.parse(@browser.url)
    prop_hash['sku_id'] = params['skuId'].first
    prop_hash['id'] = params['id'].first
    return prop_hash
  end

  def update_prop_hash_with_prices(prop_hash)
    html_doc = Nokogiri::HTML(@browser.html)
    promo_price = html_doc.css('.tm-price').first.text.to_f
    original_price = find_original_price(html_doc)
    prop_hash['promo_price'] = promo_price
    prop_hash['original_price'] = original_price
    return prop_hash
  end

  def update_prop_hash_with_image(prop_hash, variant_name, variant)
    if @prop_imgs[variant_name].nil?
      doc = Nokogiri::HTML(variant.html)
      style = doc.css('a').attribute('style')
      variant_img = style.value.scan(/\(.*\)/).first.tr('()', '') unless style.nil?
      prop_hash['variant_image'] = variant_img
      @prop_imgs[variant_name] = variant_img
    else
      prop_hash['variant_image'] = @prop_imgs[variant_name]
    end
    return prop_hash
  end

  def find_original_price(html_doc)
    price = html_doc.css('.tm-promo-price .tm-price').text.to_f
    if price == 0
      price = html_doc.css('.tm-price-cur .tm-price').text.to_f
    end
    price
  end

  def reformat_data
    product_attrs = {
      "title": "Burton Custom Freestyle 151",
      "body_html": "<strong>Good snowboard!<\/strong>",
      "vendor": "Burton",
      "product_type": "Snowboard",
      "images": [
        {'src': 'https://arcservices.org/content/uploads/sites/23/2017/02/catalog_detail_image_large.jpg'},
        {'src': 'https://rukminim1.flixcart.com/image/704/704/j1wgjgw0/t-shirt/g/m/u/xxl-ts900805-ghpc-original-imaeqyhsfq6zweum.jpeg?q=70'}
      ]
    }

    attrs = {'title' => @title}
    body_html = ""
    @images.each do |image|
      body_html += "<img src=#{image} alt='' style='display: block; margin-left: auto; margin-right: auto;'>"
    end
    attrs['body_html'] = body_html
    attrs['options'] = []
    @variants.first['props'].each { |prop, _| attrs['options'] << {'name' => prop} }

    variants = []
    @variants.each { |variant| variants << create_variant(variant) }

    attrs['variants'] = variants

    return attrs
  end

  def create_variant(variant)
    data = {
        "compare_at_price" => variant['original_price'],
        "fulfillment_service" => "manual",
        "inventory_management" => "shopify",
        "inventory_policy" => "continue",
        "inventory_quantity" => 10,
        "price" => variant['original_price'],
        "product_id" => variant['id'].to_i,
        "requires_shipping" => true,
        "sku" => variant['sku_id'],
        "title" => "pink#{rand(100)}",
      }

    variant['props'].each_with_index do |prop, index|
      option = "option#{index+1}"
      data[option] = prop[1]
    end
    return data
  end



end
