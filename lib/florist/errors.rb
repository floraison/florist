
class Florist::FloristError < StandardError

  attr_reader :worklist

  def initialize(message, worklist=nil)

    super(message)
    @worklist = worklist
  end
end

class Florist::UnauthorizedError < Florist::FloristError
end

