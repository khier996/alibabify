class ItemApiMonitorWorker
  include Sidekiq::Worker

  def perform(options = {product_count: 3})
    ItemApiMonitor.monitor(options[:product_count])
  end
end

