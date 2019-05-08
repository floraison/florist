
class Florist::FloristModel < ::Flor::FlorModel

  class << self

    attr_accessor :worklist
  end

  def worklist; self.class.worklist; end
end


require 'florist/models/task'
require 'florist/models/transition'
require 'florist/models/assignment'
require 'florist/models/transition_assignment'


Flor.add_model(:tasks, Florist, 'florist_')
Flor.add_model(:transitions, Florist, 'florist_')
Flor.add_model(:assignments, Florist, 'florist_')
#Flor.add_model(:transitions_assignments, Florist, 'florist_')
  #
  # So that `@unit.tasks` et al can be called

