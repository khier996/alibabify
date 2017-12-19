class Translator
  require 'open-uri'

  def self.translate(query)
    app_id = '20171218000105910'
    app_secret = '4vG8X1gOyHRnCrEHJcZ3'
    salt = 1
    sign = Digest::MD5.hexdigest("#{app_id}#{query}#{salt}#{app_secret}")

    encoded_query = URI.encode(query)
    url = "https://fanyi-api.baidu.com/api/trans/vip/translate/?q=#{encoded_query}&from=zh&to=vie&appid=#{app_id}&salt=#{salt}&sign=#{sign}"

    res = HTTParty.get(url)
    if res.code < 400
      return res.parsed_response['trans_result'].first['dst']
    else
      return query
    end
  end
end
