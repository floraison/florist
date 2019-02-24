
module Florist

  VERSION = '0.16.0'
end

require 'flor'
require 'flor/unit'

require 'florist/task'
require 'florist/taskers'


module Florist

  class << self

    def to_blob(o)

      o ? Flor::Storage.to_blob(o) : nil
    end
  end
end

