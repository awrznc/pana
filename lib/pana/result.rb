class Result
  attr_reader :result, :message

  def initialize(result, message)
    @result = result
    @message = message
  end

  def ok?
    return !self.error?
  end

  def error?
    return false if @message == nil
    return false if @message.empty?
    return true
  end
end
