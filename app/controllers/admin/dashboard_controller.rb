class Admin::DashboardController < ShopifyApp::AuthenticatedController
  require 'watir'
  require 'nokogiri'
  require 'open-uri'

  def index
  end

  def bulk_upload
  end

  def parse_pages

    urls = params.select { |param,_| param.match(/url_\d*/) }
    urls = urls.map do |_, url|
      url.sub(/&skuId=\d*/, '') # removing skuId from url
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
