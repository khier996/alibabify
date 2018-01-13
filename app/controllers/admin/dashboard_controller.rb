class Admin::DashboardController < ShopifyApp::AuthenticatedController
  require 'watir'
  require 'nokogiri'
  require 'open-uri'

  def index
    @products = ShopifyAPI::Product.find(:all, :params => {:limit => 10})
  end

  def bulk_upload
  end

  def parse_pages
    ProductParser.new.parse(params)
  end

  def update_products
    ProductUpdater.new.update_products(Product.all)
  end
end
