class Translator
  require 'open-uri'

  def initialize
    @dictionary = Dictionary.new
  end

  def translate(query, options={})
    translation = @dictionary.find(query)
    return translation unless translation.blank?

    translation = baidu_translate(query)
    @dictionary.write(query, translation) if options[:remember] and !translation.blank?
    return translation
  end

  private

  def baidu_translate(query)
    url = baidu_url(query)
    res = HTTParty.get(url)
    if res.code < 400 && res.parsed_response['trans_result']
      translation = res.parsed_response['trans_result'].first['dst']
      return translation
    else
      # need to send email in case of translation error
      return query
    end
  end

  def baidu_url(query)
    app_id = '20171218000105910'
    app_secret = '4vG8X1gOyHRnCrEHJcZ3'
    salt = 1
    encoded_query = URI.encode(query)
    sign = Digest::MD5.hexdigest("#{app_id}#{query}#{salt}#{app_secret}")
    return "https://fanyi-api.baidu.com/api/trans/vip/translate/?q=#{encoded_query}&from=zh&to=vie&appid=#{app_id}&salt=#{salt}&sign=#{sign}&"
  end
end
