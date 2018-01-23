class Dictionary
  require 'redis'

  def initialize
    @redis = Redis.new(port: 6379, db: 1)
  end

  def find(phrase)
    return unless phrase.is_a? String
    translation = @redis.get(phrase)
    translation
  end

  def write(original, translation)
    @redis.set(original, translation)
    write_prefixes(original)
  end

  def edit_entry(original, translation)
    @redis.set(original, translation)
  end

  def complete(prefix, count)
    start = @redis.zrank(:chinese_words, prefix)
    return {} unless start
    originals = []
    rangelen = 50

    while originals.count < count
      range = @redis.zrange(:chinese_words, start, start+rangelen-1)
      break if !range or range.length == 0
      start += rangelen
      range.each do |entry|
        minlen = [entry.length, prefix.length].min
        break if entry[0...minlen] != prefix[0...minlen]
        originals << entry[0...-1] if entry[-1] == "*"
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

  def write_prefixes(word)
    (0..word.length - 1).each do |index|
      prefix = word[0..index]
      @redis.zadd(:chinese_words, 0, prefix)
    end
    @redis.zadd(:chinese_words, 0, word + '*') # star symbol - '*' - means that this is an actual word, not a prefix
  end
end
