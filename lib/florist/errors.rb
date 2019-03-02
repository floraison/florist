
class Florist::FloristError < StandardError

  attr_reader :worklist

  def initialize(message, worklist=nil)

    super(message)
    @worklist = worklist
  end
end

class Florist::UnauthorizedError < Florist::FloristError
  def code; 401; end
end
class Florist::ConflictError < Florist::FloristError
  def code; 409; end
end

