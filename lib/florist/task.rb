
module Florist

  class << self

#    def tasks(db)
#
#      Class.new(Florist::Task) do
#        self.dataset = db[:florist_tasks]
#      end
#    end
#
#    def assignments(db)
#
#      Class.new(Florist::TaskAssignment) do
#        self.dataset = db[:florist_task_assignments]
#      end
#    end
  end
end

class Florist::Task < ::Flor::FlorModel

  #
  # accessors et al

  alias message data

  def tasker; message['tasker']; end

  def taskname; message['taskname']; end
  alias task_name taskname

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

#  def assignments
#
#    @assignment_model ||=
#      Florist.assignments(db)
#
#    @assignments ||= @assignment_model
#      .where(task_id: id)
#      .order(:ctime)
#      .all
#      .each { |a| a.task = self }
#  end
#  def assignment; assignments.first; end

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
  # actions

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

  def queue_message(msg)

    now = Flor.tstamp

    db.transaction do

      sq = db[:florist_transitions].where(task_id: id)

      tc = db[:florist_tasks].where(id: id).delete
      ac = db[:florist_assignments].where(transition_id: sq.select(:id)).delete
      sc = sq.delete

      db[:flor_messages]
        .insert(
          domain: domain,
          exid: exid,
          point: 'return',
          content: Flor::Storage.to_blob(msg),
          status: 'created',
          ctime: now,
          mtime: now)

      tc
    end
  end
end

class Florist::Transition < ::Flor::FlorModel

  #attr_accessor :task
end

class Florist::Assignment < ::Flor::FlorModel

  #attr_accessor :task
end

Flor.add_model(:tasks, Florist, 'florist_')
Flor.add_model(:transitions, Florist, 'florist_')
Flor.add_model(:assignments, Florist, 'florist_')

