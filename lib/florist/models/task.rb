
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

    @flor_model_cache_payload ||=
      (latest_transition_payload || message['payload'])
  end

  alias fields payload

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

    transitions.last
  end

  alias transition last_transition

  def transitions

    @flor_model_cache_transitions ||=
      worklist.transition_table
        .where(task_id: id, status: 'active')
        .order(:id)
        .all
  end

  def state

    last_transition.state
  end

  def tname

    last_transition.name
  end

  def assignment

    last_transition.assignment
  end

  def assignments

    last_transition.assignments
  end

  def all_assignments

    @flor_model_cache_all_assignments ||=
      worklist.assignment_table
        .where(task_id: id, status: 'active')
        .order(:id)
        .all
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

  def to_h

    h = super
    h[:state] = state
    h[:transitions] = transitions.collect(&:to_h)
    h[:assignments] = all_assignments.collect(&:to_h)
    h[:current_assignment_ids] = assignments.collect(&:id);
    h[:last_transition_id] = assignments.collect(&:id);

    h
  end

  protected

  def latest_transition_content(key)

    k = key.to_s

    transitions
      .reverse
      .select { |s| s.data }
      .each { |s| s.data.each { |e| return e[k] if e.has_key?(k) } }

    nil
  end

  def latest_transition_payload

    latest_transition_content('payload')
  end

  def transition_and_or_assign(state, *as)

    opts = is_opts_hash?(as.last) ? as.pop : {}
    assignments = extract_assignments(as)

    name = opts[:transition_name] || opts[:tname] || determine_tname(state)

    sid = nil

    db.transaction do

      now = Flor.tstamp

      meta = { tstamp: now }
        #
      pl = opts[:payload] || opts[:fields]
      meta[:payload] = pl if pl
        #
      met = opts[:meta]
      meta.merge!(met) if met  # TODO spec me

      lt = last_transition
      sid = lt.id

      n = db[:florist_tasks]
        .where(id: id, mtime: mtime)
        .update(mtime: now)

      fail Florist::ConflictError('task outdated, update failed') \
        if n != 1

      if lt.state != state || (opts[:force] || opts[:override])

        sid = db[:florist_transitions]
          .insert(
            task_id: id,
            name: name,
            state: state,
            description: nil,
            user: opts[:user] || worklist.user,
            domain: opts[:domain] || worklist.domain,
            content: meta.size > 1 ? Flor.to_blob([ meta ]) : nil,
            ctime: now,
            mtime: now,
            status: 'active')

      else

        cols = { mtime: now }
        cols[:content] = Flor.to_blob((lt._data || []) << meta) if meta.size > 1

        n = db[:florist_transitions]
          .where(id: sid, mtime: lt.mtime)
          .update(cols)

        fail Florist::ConflictError("task transition outdated, update failed") \
          if n != 1
      end

      if assignments.any?

        ah = all_assignments.inject({}) { |r, a| r[a.id] = r[a.to_ra] = a; r }
        as = assignments

        old_aids, new_aids = assignments
          .inject([ [], [] ]) { |(o, n), a|
            case a
            when Array
              if aa = ah[a]
                o << aa.id
              else
                n << insert_assignment(now, a)
              end
            when :all
              o.concat(as.collect(&:id))
            when :first, :last
              aa = as.send(a)
              o << aa.id if aa
            when Integer
              aa = ah[a]
              o << aa.id if aa
            #else
              # no new/old assignment id
            end
            [ o, n ] }

# TODO .where(id: old_aid0, mtime: old_mtime0)
#      fail if update_count != old_aids_count
        db[:florist_assignments]
          .where(id: old_aids)
          .update(mtime: now)

        db[:florist_transitions_assignments]
          .import(
            [ :task_id, :transition_id, :assignment_id,
              :ctime, :mtime, :status ],
            (old_aids + new_aids).collect { |aid|
              [ id, sid, aid, now, now, 'active' ] })
      end
    end

    sid
  end

  def insert_assignment(now, (rtype, rname))

    db[:florist_assignments]
      .insert(
        task_id: id,
        resource_type: rtype,
        resource_name: rname,
        content: nil,
        description: nil,
        ctime: now,
        mtime: now,
        status: 'active')
          # hopefully, your Sequel adapater returns the newly inserted :id
  end

  def is_opts_hash?(o)

    o.is_a?(Hash) &&
    (o.keys.map(&:to_s) & %w[ resource_name rname resource_type rtype ]).empty?
  end

  def extract_assignments(as)

    return [ as ] \
      if as.collect(&:class) == [ String, String ]

    as.collect { |a|
      case a
      when Array, Integer, :all, :first, :last
        a
      when Hash
        h = Flor.to_string_keyed_hash(a)
        t = h['resource_type'] || h['rtype'] || 'user'
        n = h['resource_name'] || h['rname']
        fail ArgumentError.new("no resource_name in #{h.inspect}") unless n
        [ t, n ]
      else
        fail ArgumentError.new("not an assignment #{a.inspect}")
      end }
  end

  def determine_tname(state)

    case state
    when 'created' then 'create'
    when 'offered' then 'offer'
    when 'allocated' then 'allocate'
    when 'started' then 'start'
    when 'suspended' then 'suspend'
    when 'failed' then 'fail'
    when 'completed' then 'complete'
    else "to-#{state}"
    end
  end
end

