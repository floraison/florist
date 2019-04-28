
# Empty, permit all, implementation
#
class Florist::Controller

  attr_reader :worklist

  def initialize(worklist)

    @worklist = worklist
  end

  def may?(right, domain)

    true
  end
end

