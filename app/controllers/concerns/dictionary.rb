class Dictionary
  require 'redis'

  def initialize
    @redis = Redis.new(port: 6379, db: 1)
  end

  def find(phrase)
    return unless phrase.is_a? String
    translation = @redis.get(phrase)
    translation.split('**').first if translation
  end

  def write(original, translation)
    @redis.set(original, translation)
    @redis.sadd(translation, original)
    write_prefixes(original, 'ch')
    write_prefixes(translation, 'vn')
  end

  def edit_entry(original, new_translation, old_translation)
    resp1 = @redis.set(original, new_translation) == 'OK'
    resp2 = @redis.srem(old_translation, original)
    resp3 = @redis.sadd(new_translation, original)
    resp4 = @redis.zrem(:prefixes, old_translation + '**vn') if @redis.smembers(old_translation).empty?
    resp4 = true if resp4.nil?
    write_prefixes(new_translation, 'vn')

    return resp1 && resp2 && resp3 && resp4
  end

  def complete(prefix, count)
    start = @redis.zrank(:prefixes, prefix)
    return {} unless start
    originals = []
    rangelen = 50

    while originals.count < count
      range = @redis.zrange(:prefixes, start, start+rangelen-1)
      break if !range or range.length == 0
      start += rangelen
      range.each do |entry|
        minlen = [entry.length, prefix.length].min
        break if entry[0...minlen] != prefix[0...minlen]
        originals << entry[0..-5] if entry[-4..-1] == '**ch'
        originals.concat(@redis.smembers(entry[0..-5])) if entry[-4..-1] == '**vn'
      end
    end

    return {} if originals.empty?

    translations = @redis.mget(originals)
    results = {}

    originals.each_with_index do |original, index|
      results[original] = translations[index]
    end

    return results
  end # def complete

  private

  def write_prefixes(word, language)
    (0..word.length - 1).each do |index|
      prefix = word[0..index]
      @redis.zadd(:prefixes, 0, prefix)
    end
    @redis.zadd(:prefixes, 0, word + "**#{language}") # star symbol - '*' - means that this is an actual word, not a prefix
  end
end
