
class Florist::FloristModel < ::Flor::FlorModel

  class << self

    attr_accessor :worklist
  end

  def worklist; self.class.worklist; end
end


class Florist::Task < ::Florist::FloristModel

  #
  # accessors et al

  def message; data['message']; end

  def task_name; taskname; end

  def attl; message['attl']; end
  alias atta attl
  alias atts attl

  def attd; message['attd']; end
  alias atth attd

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

  def payload

    @payload ||=
      last_transition_payload || message['payload']
  end

  alias fields payload

  def refresh

    @payload = nil
    @transition = nil

    super
  end

  #
  # 'update' methods

  def push_payload(h)

    c = nil

    db.transaction do

      s = transition
      now = Flor.tstamp
      c = (s._data || []) << { 'tstamp' => now, 'payload' => h }

      n = db[:florist_tasks]
        .where(id: id, mtime: mtime)
        .update(mtime: now)

      fail Florist::ConflictError("task outdated, update failed") \
        if n != 1

      n = db[:florist_transitions]
        .where(id: s.id, mtime: s.mtime)
        .update(content: Flor.to_blob(c), mtime: now)

      fail Florist::ConflictError("task transitions outdated, update failed") \
        if n != 1
    end

    c
  end

  #
  # 'graph' methods

  def last_transition

    @transition ||=
      worklist.transition_table
        .where(task_id: id)
        .reverse(:id)
        .first
  end

  alias transition last_transition

  def transitions

    worklist.transition_table
      .where(task_id: id)
      .order(:id)
      .all
  end

  def state

    last_transition.state
  end

  def assignment

    last_transition.assignment
  end

  def assignments

    last_transition.assignments
  end

  #
  # transition 'methods'

  def transition_to_offered(*as)

    transition_and_or_assign('offered', *as)
  end

  def transition_to_allocated(*as)

    transition_and_or_assign('allocated', *as)
  end

  alias offer transition_to_offered
  alias allocate transition_to_allocated

#  def return(opts={})
#
#    m = Flor.dup(message)
#    m['point'] = 'return'
#    m['payload'] = Flor.to_string_keyed_hash(payload)
#
#    queue_message(m)
#  end
#  alias reply return
#
#  def return_error(err, opts={})
#
#    m = Flor.to_error_message(message, err)
#    #m['payload'] = payload
#
#    queue_message(m)
#  end
#  alias reply_with_error return_error

  protected

  def last_transition_payload

    s = worklist.transition_table
      .select(:content)
      .where(task_id: id).exclude(content: nil)
      .reverse(:id)
      .first

    s ? Flor.from_blob(s[:content]).last['payload'] : nil
  end

  def transition_and_or_assign(state, *as)

    opts = as.last.is_a?(Hash) ? as.pop : {}
    assignments = extract_assignments(as)

    db.transaction do

      now = Flor.tstamp

      pl = opts[:payload] || opts[:fields]
      pl = { tstamp: now, payload: pl } if pl

      s = last_transition
      sid = s.id

      n = db[:florist_tasks]
        .where(id: id, mtime: mtime)
        .update(mtime: now)

      fail Florist::ConflictError("task outdated, update failed") \
        if n != 1

      if s.state != state

        sid = db[:florist_transitions]
          .insert(
            task_id: id,
            state: state,
            description: nil,
            user: opts[:user] || worklist.user,
            domain: opts[:domain] || worklist.domain,
            content: pl ? Flor.to_blob([ pl ]) : nil,
            ctime: now,
            mtime: now)

      else

        cols = { mtime: now }
        cols[:content] = Flor.to_blob((s._data || []) << pl) if pl

        n = db[:florist_transitions]
          .where(id: sid, mtime: s.mtime)
          .update(cols)

        fail Florist::ConflictError("task transition outdated, update failed") \
          if n != 1
      end

      db[:florist_assignments]
        .import(
          [ :transition_id, :resource_type, :resource_name, :content,
            :description, :ctime, :mtime, :status ],
          assignments.map { |a|
            [ sid, a[0], a[1], nil,
              nil, now, now, 'active' ] }
        ) if assignments.any?
    end
  end

  def extract_assignments(as)

    acs = as.collect(&:class)

    if acs == [ String, String ]
      [ as ]
    elsif acs.uniq == [ Array ]
      as
        .collect { |a| [ a[0], a[1] ] }
    elsif acs.uniq == [ Hash ]
      as
        .collect { |h|
          h = Flor.to_string_keyed_hash(h)
          t = h['resource_type'] || h['rtype'] || 'user'
          n = h['resource_name'] || h['rname']
          fail ArgumentError.new("no resource_name in #{h.inspect}") unless n
          [ t, n ] }
    else
      fail ArgumentError.new(
        "couldn't figure out assignment list out of #{as.inspect}")
    end
  end
end


class Florist::Transition < ::Florist::FloristModel

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

  def rtype; resource_type; end
  def rname; resource_name; end
end


Flor.add_model(:tasks, Florist, 'florist_')
Flor.add_model(:transitions, Florist, 'florist_')
Flor.add_model(:assignments, Florist, 'florist_')
  #
  # So that `@unit.tasks` et al can be called

