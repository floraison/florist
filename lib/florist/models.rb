
class Florist::FloristModel < ::Flor::FlorModel

  class << self

    attr_accessor :worklist

    def insert_from_h(h)

      cols = columns - [ :id ]

      ih = cols.inject({}) { |r, k| r[k] = h[k.to_s]; r }

      ih[:content] = Flor.to_blob(h['data']) if h.has_key?('data')

      self.insert(ih)
    end
  end

  def worklist; self.class.worklist; end
end


require 'florist/models/task'
require 'florist/models/transition'
require 'florist/models/assignment'
require 'florist/models/transition_assignment'


Flor.add_model(:tasks, Florist, 'florist_')
#Flor.add_model(:transitions, Florist, 'florist_')
#Flor.add_model(:transitions_assignments, Florist, 'florist_')
Flor.add_model(:assignments, Florist, 'florist_')
  #
  # So that `@unit.tasks` et al can be called

