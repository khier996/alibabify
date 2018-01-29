class Admin::DashboardController < ShopifyApp::AuthenticatedController
  require 'watir'
  require 'nokogiri'
  require 'open-uri'

  def index
    @safe_to_use = ItemApiMonitor.safe_to_use?
  end

  def bulk_upload
    @collections = ShopifyAPI::CustomCollection.find(:all)
  end

  def parse_pages
    urls = params.select { |param,_| param.match(/url_\d*/) }
    collections = params.select { |param| param.match(/collections_\d*/)}

    urls = urls.map do |url_key, url|
      url = url.sub(/&skuId=\d*/, '') # removing skuId from url
      url_num = url_key.split('_').last
      cols = collections["collections_#{url_num}"]
      {url: url, collections: cols}
    end
    BulkUploadWorker.perform_async(urls, @shop_session.token)
    # ProductParser.new.parse(urls, @shop_session.token) # for tests on local machine
  end

  def update_products
    ProductUpdater.new.update_products(Product.all)
  end

  def dictionary_lookup
  end
end
