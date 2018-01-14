class BulkUploadWorker
  include Sidekiq::Worker

  def perform(urls, session_token)
    ProductParser.new.parse(urls, session_token)
  end
end
