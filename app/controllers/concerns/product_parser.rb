class ProductParser
  require 'headless'

  def initialize
    @translator = Translator.new
    @redis = Redis.new(port: 6379, db: 0)
  end

  def parse(urls, session_token)
    session = ShopifyAPI::Session.new('kurut.shopify.com', session_token)
    ShopifyAPI::Base.activate_session(session)

    urls.each do |url_obj|
      begin
        url = url_obj['url']
        next if url.blank? or not_tmall(url)
        current_url = url # for saving in error
        parse_product(url_obj)
        close_browser
      rescue => exception
        Error.create(url: current_url,
                     exception: exception.message,
                     backtrace: exception.backtrace.to_json)
        delete_failed_product
        close_browser
        next
      ensure
        close_browser
      end
    end
    @redis.set('referer_url', urls.last) unless not_tmall(urls.last)
  end

  private

  def not_tmall(url)
    return false unless url
    !url.include?('https://detail.tmall.com/item.htm?')
  end

  def close_browser
    @browser.close if @browser
    @browser = nil
    @headless.destroy if @headless
    @headless = nil
  end

  def parse_product(url_obj)
    url = url_obj['url']
    @product = ShopifyAPI::Product.new
    @product.attributes = get_product_attrs(url)
    @product.save

    if @product.errors.messages.empty?
      create_variant_images
      @product.taobao_id = @taobao_id
      @product.original_title = @original_title
      @db_product = Product.copy_shopify(@product)
      save_unparsed_skus if @product.variants.count < 100
      save_collects(url_obj['collections'])
    end
  end

  def save_collects(collections)
    collections.each do |collection_id|
      collect = ShopifyAPI::Collect.create(collection_id: collection_id, product_id: @product.id)
    end
  end

  def create_variant_images
    @variant_images.each do |option, images|
      images.each do |prop_name, image_src|
        new_image = {'product_id': @product.id, 'src': image_src}
        prop_name = @translated_props[prop_name]
        variants = @product.variants.select { |v| v.send(option) == prop_name }
        variant_ids = variants.map { |v| v.id }
        new_image['variant_ids'] = variant_ids
        new_image = ShopifyAPI::Image.create(new_image)
      end
    end
  end

  def find_image_options
    @product.images.each do |image|
      @product.options.each_with_index do |option, index|
        next unless image.respond_to?(:prop) # not a variant image
        if image.prop['prop_name'] == option.name
          image.option = "option#{index + 1}"
        end
      end
    end
  end

  def get_product_attrs(url)
    @headless ||= Headless.new(display: rand(99))
    @headless.start
    @browser ||= Watir::Browser.new :chrome, :switches => %w[--no-sandbox]

    # @browser ||= Watir::Browser.new :chrome # for tests on local machine

    @browser.goto(url)
    @browser.wait(5)

    props = @browser.dls(css: '.tb-prop')
    props = filter_props(props)
    @variants = []
    @prop_imgs = {}
    @product_images = []
    @body_images = [] #images for body html
    @variant_images = {}

    fetch_sku_infos
    find_variants(props, 0, {'props' => {}})
    find_images
    return reformat_data
  end

  def fetch_sku_infos
    query = @browser.url.split('?').second
    params = CGI.parse(query)
    @taobao_id = params['id'].first
    @sku_infos = SkuInfoFetcher.fetch(@taobao_id)
  end

  def find_images
    @browser.execute_script('window.scrollBy(0, 1000)')
    # sleep(1)
    @browser.wait(1)
    doc = Nokogiri::HTML(@browser.html)
    find_product_images(doc)
    find_body_images(doc)
  end

  def find_product_images(doc)
    images = doc.css('#J_UlThumb img')
    return if images.empty?
    doc.css('#J_UlThumb img').each do |img|
      img_src = img.attributes['src'].value
      img_src = 'https:' + img_src.sub('60x60q90', '800x800q90')
      @product_images << {'src': img_src}
    end
  end

  def find_body_images(doc)
    @title = doc.css('.tb-detail-hd h1').text.gsub(/\t|\n/, '')
    images = doc.css('#description img')
    images.each do |image|
      lazyload = image.attributes['data-ks-lazyload']
      src = lazyload ? lazyload.value : image.attributes['src'].value
      @body_images << src
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

    store_variant_images(level, props[level].ul)

    variants.each do |variant|
      break if @variants.length == 100
      variant_name = variant.text.gsub(/\n已选中/, '')
      click(variant)

      if level >= props.count - 1
        next unless @browser.url.include?('skuId')
        # sleep(0.1)
        @browser.wait(0.1)
        prop_hash = update_prop_hash_with_ids(prop_hash, variant)
        prop_hash['props'] = prop_hash['props'].clone
        prop_hash['props'][prop_name] = variant_name
        prop_hash = update_prop_hash_with_prices(prop_hash)
        @variants << prop_hash.clone if prop_hash['sku_id']

        variant.as.first.click if variants.last == variant #unclick the variant to make sure the lower level variant is clickable
        # sleep(0.5)
        @browser.wait(0.1)
        next
      else
        prop_hash['props'] = prop_hash['props'].clone
        prop_hash['props'][prop_name] = variant_name
        find_variants(props, level+1, prop_hash)
      end
    end
  end

  def click(variant)
    (1..3).each do |n|
      begin
        variant.as.first.click
        break
      rescue
        @browser.execute_script('scrollBy(0, 50)')
        next
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

  def store_variant_images(level, variant_list)
    option = "option#{level + 1}"
    return unless @variant_images[option].nil?
    @variant_images[option] = {}

    doc = Nokogiri::HTML(variant_list.html)
    variants = doc.css('li')
    first_variant_style = variants.first.css('a').first.attributes['style']
    return unless first_variant_style # if first variant doesn't have style, other variants most likely also don't have it

    variants.each do |variant|
      style = variant.css('a').first.attributes['style']
      variant_img = style.value.scan(/\(.*\)/).first.tr('()', '') unless style.nil?
      variant_img = 'https:' + variant_img.sub('jpg_40x40q90', 'jpg_600x600q90')
      variant_name = variant.attributes['title'].value

      @variant_images[option][variant_name] = variant_img
    end
  end

  def update_prop_hash_with_ids(prop_hash, variant)
    reclick(variant) unless @browser.url.include?('skuId')
    params = CGI.parse(@browser.url)
    prop_hash['sku_id'] = params['skuId'].first
    prop_hash['id'] = params['id'].first

    return prop_hash
  end

  def reclick(variant)
    # sleep(3)
    @browser.wait(1)
    variant.as.first.click
    # sleep(3)
    @browser.wait(1)
    variant.as.first.click
    # sleep(3)
    @browser.wait(1)
  end

  def update_prop_hash_with_prices(prop_hash)
    if @sku_infos.empty?
      read_html_prices(prop_hash)
    else
      read_sku_prices(prop_hash)
    end
    return prop_hash
  end

  def read_html_prices(prop_hash)
    html_doc = Nokogiri::HTML(@browser.html)
    promo_price = html_doc.css('.tm-price').first.text.to_f
    original_price = find_original_price(html_doc)
    prop_hash['promo_price'] = promo_price
    prop_hash['original_price'] = original_price
  end

  def read_sku_prices(prop_hash)
    sku_id = prop_hash['sku_id']
    prop_hash['promo_price'] = @sku_infos[sku_id]['promo_price']
    prop_hash['original_price'] = @sku_infos[sku_id]['original_price']
  end

  def find_original_price(html_doc)
    price = html_doc.css('.tm-promo-price .tm-price').text.to_f
    price = html_doc.css('.tm-price-cur .tm-price').text.to_f if price == 0
    return price
  end

  def reformat_data
    translate_attributes

    attrs = {'title' => @title}
    body_html = ""
    @body_images.each do |image|
      body_html += "<img src=#{image} alt='' style='display: block; margin-left: auto; margin-right: auto;'>"
    end
    attrs['body_html'] = body_html
    attrs['options'] = []

    @variants.first['props'].each { |prop, _| attrs['options'] << {'name' => @translated_props[prop]} }

    attrs['variants'] = @variants.map { |variant| create_variant(variant) }

    attrs['images'] = @product_images

    attrs['metafields']  = [{key: 'taobao_id', value: @taobao_id, namespace: 'alibabify_app', value_type: 'string'}]
    return attrs
  end

  def translate_attributes
    @original_title = @title
    @title = @translator.translate(@title)

    @translated_props = {}
    @variants.first['props'].each do |prop, _|
      @translated_props[prop] = @translator.translate(prop, remember: true)
    end
  end

  def create_variant(variant)
    data = {
        "compare_at_price" => variant['original_price'],
        "fulfillment_service" => "manual",
        "inventory_management" => "shopify",
        "inventory_policy" => "continue",
        "inventory_quantity" => 10,
        "price" => variant['promo_price'],
        "requires_shipping" => true,
        "sku" => variant['sku_id'],
        "title" => "pink#{rand(100)}",
      }

    variant['props'].each_with_index do |prop, index|
      option = "option#{index+1}"

      if prop[1] == prop[1].to_i.to_s # prop is a number and doesn't need translation
        translated_prop = prop[1]
      else
        translated_prop = @translated_props[prop[1]] || @translator.translate(prop[1], remember: true)
        @translated_props[prop[1]] = translated_prop
      end
      data[option] = translated_prop
    end
    return data
  end

  def save_unparsed_skus
    saved_skus = @product.variants.map { |variant| variant.sku }

    @sku_infos.each do |sku, _|
      break if @db_product.variants.count >= 100
      save_unparsed_sku(sku) unless saved_skus.include?(sku)
    end
  end

  def save_unparsed_sku(sku)
    Variant.create(sku: sku,
                   product_id: @db_product.id,
                   parsed: false)
  end

  def delete_failed_product
    return unless @product
    return if @product.id.nil?

    @product.destroy
    @db_product.destroy
  end
end
