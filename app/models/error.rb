class Error < ActiveRecord::Base
  def p_trace
    JSON.parse(self.backtrace).each do |trace|
      p trace
    end
    nil
  end
end
