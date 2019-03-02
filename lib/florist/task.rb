
class Florist::FloristModel < ::Flor::FlorModel

  class << self

    attr_accessor :worklist
  end

  def worklist; self.class.worklist; end
end

class Florist::Task < ::Florist::FloristModel

  #
  # accessors et al

  alias message data

  def task_name; taskname; end

  def attl; message['attl']; end
  alias atta attl
  alias atts attl

  def attd; message['attd']; end
  alias atth attd

  def payload

    @payload ||= _data['payload']
  end

  def payload=(h)

    @payload = h
  end

  alias fields payload
  alias fields= payload=

  def vars; message['vars']; end
  alias vard vars

  def execution

    return nil unless db.table_exists?(:flor_executions)

    exes = db[:flor_executions]

    @execution_class ||=
      Class.new(Flor::Execution) do
        self.dataset = exes
      end

    @execution_class[exid: exid]
  end

  #
  # 'graph' methods

  def last_transition

    worklist.transition_table
      .where(task_id: id)
      .reverse(:id)
      .limit(1)
      .first
  end

  alias transition last_transition

  #
  # transition 'methods'

  def offer(*as)

    worklist.transition_to_offered(self, *as)
  end

  def allocate(*as)

    worklist.transition_to_allocated(self, *as)
  end

#  def return(opts={})
#
#    # [o] TODO current payload (default) OR
#    # [ ] TODO original payload OR
#    # [ ] TODO overlay payload OR
#    # [ ] TODO new payload
#
#    m = Flor.dup(message)
#    m['point'] = 'return'
#    m['payload'] = Flor.to_string_keyed_hash(payload)
#
#    queue_message(m)
#  end
#
#  alias reply return
#
#  def return_error(err, opts={})
#
#    # [o] TODO current payload (default) OR
#    # [ ] TODO original payload OR
#    # [ ] TODO overlay payload OR
#    # [ ] TODO new payload
#
#    m = Flor.to_error_message(message, err)
#    #m['payload'] = payload
#
#    queue_message(m)
#  end
#
#  alias reply_with_error return_error
#
#  def assign(resource_type, resource_name, opts={})
#
#    now = Flor.tstamp
#    typ = opts[:assignment_type] || opts[:type] || ''
#    ame = opts[:assignment_meta]
#    ast = opts[:assigmment_status] || opts[:status] || 'active'
#
#    assignment_id = db[:florist_task_assignments]
#      .insert(
#        task_id: id,
#        type: typ,
#        resource_type: resource_type,
#        resource_name: resource_name,
#        content: Florist.to_blob(ame),
#        ctime: now,
#        mtime: now,
#        status: ast)
#
#    @assignments = nil
#      # forces reload at next #assignments call
#
#    assignment_id
#  end

  protected
end

class Florist::Transition < ::Florist::FloristModel

  #attr_accessor :task

  def assignments

    worklist.assignment_table
      .where(transition_id: id)
      .order(:id)
      .all
  end

  def assignment

    assignments.first
  end
end

class Florist::Assignment < ::Florist::FloristModel

  #attr_accessor :task
end

Flor.add_model(:tasks, Florist, 'florist_')
Flor.add_model(:transitions, Florist, 'florist_')
Flor.add_model(:assignments, Florist, 'florist_')
  #
  # So that `@unit.tasks` et al can be called

