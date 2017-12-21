class Admin::DashboardController < ShopifyApp::AuthenticatedController
  require 'watir'
  require 'nokogiri'
  require 'open-uri'

  def index
    @products = ShopifyAPI::Product.find(:all, :params => {:limit => 10})
    @product = ShopifyAPI::Product.new

    begin
      @product.attributes = get_product_attrs
      @product.save
    ensure
      @browser.close
    end

    if @product.errors.messages.empty?
      update_variant_images
    end
  end

  def kurut
  end

  private

  def update_variant_images
    map_images
    find_image_options
    @product.variants.each do |variant|
      @product.images.each do |image|
        if variant.send(image.option) == image.prop['variant_name']
          variant.image_id = image.id
          next
        end
      end
    end
    @product.save
  end

  def map_images #images returned after saving product and variant_images
    @product.images.each do |product_img|
      @variant_images.each do |prop_name, variants|
        variants.each do |variant_name, variant_img|
          # below two lines might need refactoring
          product_img_src = product_img.src.split('/products/').second.split('?').first.split('600x600q90').first + '600x600q90.jpg'
          variant_img = variant_img.split(/\/uploaded\/.*\//).second.sub('!!', '_')

          if product_img_src == variant_img
            product_img.prop = {'prop_name' => @translated_props[prop_name], 'variant_name' => @translated_props[variant_name]}
          end
        end
      end
    end
  end

  def find_image_options
    @product.images.each do |image|
      @product.options.each_with_index do |option, index|
        if image.prop['prop_name'] == option.name
          image.option = "option#{index + 1}"
        end
      end
    end
  end

  def get_product_attrs
    # url = 'https://detail.tmall.com/item.htm?spm=a230r.1.14.6.3e2e4a3dh91FYr&id=535772624331&cm_id=140105335569ed55e27b&abbucket=20'
    # url = 'https://detail.tmall.com/item.htm?spm=a230r.1.14.6.1359e702S5c2xx&id=26125852732&cm_id=140105335569ed55e27b&abbucket=9'
    url = 'https://detail.tmall.com/item.htm?spm=a230r.1.14.6.39c53556D82FMW&id=14217694831'

    @browser = Watir::Browser.new :chrome
    @browser.goto(url)
    @browser.wait(5)

    props = @browser.dls(css: '.tb-prop')
    props = filter_props(props)
    @variants = []
    @prop_imgs = {}
    @images = [] #images for body html
    @variant_images = {}
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

    store_variant_images(prop_name, props[level].ul)

    variants.each do |variant|
      break if @variants.length == 100

      variant_name = variant.text.gsub(/\n已选中/, '')
      variant.as.first.click
      if level == 0
        prop_hash['props'] = prop_hash['props'].clone
        prop_hash['props'][prop_name] = variant_name
        prop_hash = update_prop_hash_with_ids(prop_hash)
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

  def store_variant_images(prop_name, variant_list)
    doc = Nokogiri::HTML(variant_list.html)
    variants = doc.css('li')
    first_variant_style = variants.first.css('a').first.attributes['style']
    return unless first_variant_style # if first variant doesn't have style, other variants most likely also don't have it
    @variant_images[prop_name] = {}
    variants.each do |variant|
      style = variant.css('a').first.attributes['style']
      variant_img = style.value.scan(/\(.*\)/).first.tr('()', '') unless style.nil?
      variant_img = 'https:' + variant_img.sub('jpg_40x40q90', 'jpg_600x600q90')
      variant_img = 'https://img.alicdn.com/bao/uploaded/i2/' + variant_img.split(/\/uploaded\/.*\/\d*\//).second #getting rid of unnecessary part for easier comparison with return product.images
      variant_name = variant.attributes['title'].value
      @variant_images[prop_name][variant_name] = variant_img
    end
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

  def find_original_price(html_doc)
    price = html_doc.css('.tm-promo-price .tm-price').text.to_f
    if price == 0
      price = html_doc.css('.tm-price-cur .tm-price').text.to_f
    end
    price
  end

  def reformat_data
    translate_attributes

    attrs = {'title' => @title}
    body_html = ""
    @images.each do |image|
      body_html += "<img src=#{image} alt='' style='display: block; margin-left: auto; margin-right: auto;'>"
    end
    attrs['body_html'] = body_html
    attrs['options'] = []

    @variants.first['props'].each { |prop, _| attrs['options'] << {'name' => @translated_props[prop]} }

    variants = @variants.map { |variant| create_variant(variant) }
    attrs['variants'] = variants

    attrs['images'] = []
    @variant_images.each do |_, variants|
      variants.each do |_, variant_img|
        attrs['images'] << {'src': variant_img}
      end
    end

    return attrs
  end

  def translate_attributes
    @title = Translator.translate(@title)

    @translated_props = {}
    @variants.first['props'].each do |prop, _|
      @translated_props[prop] = Translator.translate(prop)
    end
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

      if prop[1] == prop[1].to_i.to_s # prop is a number and doesn't need translation
        translated_prop = prop[1]
      else
        translated_prop = @translated_props[prop[1]] || Translator.translate(prop[1])
        @translated_props[prop[1]] = translated_prop
      end
      data[option] = translated_prop
    end
    return data
  end

end
