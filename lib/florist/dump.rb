
module Florist

  class << self

    def dump(db_or_unit_or_uri, io=nil, opts=nil, &block)

      o = db_or_unit_or_uri
      list = o.is_a?(Florist::Worklist) ? o : Florist::Worklist.new(o)

      list.dump(io, opts, &block)
    end

    def load(db_or_unit_or_uri, string_or_io, opts={}, &block)

      o = db_or_unit_or_uri
      list = o.is_a?(Florist::Worklist) ? o : Florist::Worklist.new(o)

      list.load(string_or_io, opts, &block)
    end
  end
end

