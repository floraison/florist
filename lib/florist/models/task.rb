
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

    @executions ||=
      Class.new(Flor::Execution) do
        self.dataset = exes
      end

    @executions[exid: exid]
  end

  def message

    data['message']
  end

  def payload

    @flor_model_cache_payload ||=
      (latest_transition_payload || message['payload'])
  end

  alias fields payload

  #
  # 'update' methods

#  def push_payload(h)
#  def push_content(h)
#  ...

  #
  # 'graph' methods

  def last_transition

    transitions.last
  end

  alias transition last_transition

  def transitions

    @flor_model_cache_transitions ||=
      worklist.transitions
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
      worklist.assignments
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

  def transition_to_started(*as)

    transition_and_or_assign('started', *as)
  end

  def transition_to_suspended(*as)

    guard('suspend', 'started')

    transition_and_or_assign('suspended', *as)
  end

  def transition_to_failed(*as)

    # TODO mark as failed
    # TODO mark as archived

    m = message
    m['payload'] = payload
    m['point'] = 'failed'

    transition_and_or_assign('failed', *as) do

      if worklist
        worklist.return(m)
        remove
      else
        set_status('failed')
      end
    end
  end

  alias offer transition_to_offered
  alias allocate transition_to_allocated
  alias start transition_to_started
  alias suspend transition_to_suspended
  alias fail transition_to_failed

  alias pause transition_to_suspended

  def resume(*as)

    guard('resume', 'suspended')

    append_option(as, transition_name: 'resume')

    transition_and_or_assign('started', *as)
  end

  def to_h

    h = super
    h[:state] = state
    h[:transitions] = ss = transitions.collect(&:to_h)
    h[:assignments] = all_assignments.collect(&:to_h)
    h[:current_assignment_ids] = assignments.collect(&:id)
    h[:last_transition_id] = ss.last[:id]

    h
  end

  protected

  def remove

    db[:florist_tasks].where(id: id).delete

    w = { task_id: id }

    [ :florist_transitions, :florist_transitions_assignments,
      :florist_assignments ]
        .each { |t| db[t].where(w).delete }
  end

  def guard(v, s)

    raise Florist::ConflictError.new(
      "cannot #{v} task #{id} " +
      "because it is currently #{state.inspect}, not #{s.inspect}"
    ) if state != s
  end

  def append_option(assignments, opts)

    la = assignments.last

    unless is_opts_hash?(la)
      la = {}; assignments << la
    end

    opts.each { |k, v| la[k] = v }
  end

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

  def transition_and_or_assign(state, *as, &block)

    opts = is_opts_hash?(as.last) ? as.pop : {}

    assignments = extract_assignments(as)
    assignments << :current if assignments.empty?

    name = opts[:transition_name] || opts[:tname] || determine_tname(state)

    sid = nil

    db.transaction do

      ls = last_transition
      sid = ls.id

      now = Flor.tstamp

      n = db[:florist_tasks]
        .where(id: id, mtime: mtime)
        .update(mtime: now)
          #
      raise Florist::ConflictError, 'task outdated, update failed' \
        if n != 1

      if ls.state != state || (opts[:force] || opts[:override])

        scon = determine_transition_content(opts, nil, now)

        sid = db[:florist_transitions]
          .insert(
            task_id: id,
            name: name,
            state: state,
            description: nil,
            user: opts[:user] || worklist.r_type_and_name,
            domain: opts[:domain] || ls.domain,
            content: Flor.to_blob(scon),
            ctime: now,
            mtime: now,
            status: 'active')

      else

        scon = determine_transition_content(opts, ls, now)
        cols = { mtime: now, content: Flor.to_blob(scon) }

        n = db[:florist_transitions]
          .where(id: sid, mtime: ls.mtime)
          .update(cols)
            #
        raise Florist::ConflictError.new(
          'task transition outdated, update failed') if n != 1
      end

      update_assignments(now, sid, assignments) \
        if assignments.any?

      block.call if block
    end

    (refresh rescue nil) if opts[:refresh] || opts[:r]

    sid
  end

  def determine_transition_content(opts, ls, now)

    (ls ? ls.data : []) << opts
      .inject({ tstamp: now }) { |r, (k, v)|
        r[k] = v if [ :payload, :set, :unset ].include?(k)
        r }
  end

  def update_assignments(now, transition_id, assignments)

    assignments = [] if assignments.include?(:none)

    aas = all_assignments
    ah = aas.inject({}) { |r, a| r[a.id] = r[a.to_ra] = a; r }

    old_as, new_aids = assignments
      .inject([ [], [] ]) { |(o, n), a|
        case a
        when Array
          if aa = ah[a]
            o << aa
          else
            n << insert_assignment(now, a)
          end
        when :all
          o.concat(aas)
        when :current
          lsi = last_transition.id
          o.concat(aas.select { |a| a.transition_ids.include?(lsi) })
        when :first, :last
          aa = aas.send(a)
          o << aa if aa
        when Integer
          aa = ah[a]
          o << aa if aa
        when Florist::Assignment
          raise ArgumentError, "assignment #{a.id} not linked to task #{id}" \
            unless ah[a.id]
          o << a
        when Symbol
          raise ArgumentError, "not an (pseudo-)assignment #{a.inspect}"
        #else
          # no new/old assignment id
        end
        [ o, n ] }

    if old_as.any?

      n = db[:florist_assignments]
        .where { Sequel.|(*old_as.map { |a| { id: a.id, mtime: a.mtime } }) }
        .update(mtime: now)
          #
      raise Florist::ConflictError, 'task outdated, transition update failed' \
        if n != old_as.size
    end

    db[:florist_transitions_assignments]
      .import(
        [ :task_id, :transition_id, :assignment_id,
          :ctime, :mtime, :status ],
        (old_as.collect(&:id) + new_aids).collect { |aid|
          [ id, transition_id, aid,
            now, now, 'active' ] })
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
      when :self
        [ worklist.rtype, worklist.rname ]
      when Array, Integer, Symbol, Florist::Assignment
        a
      when Hash
        h = Flor.to_string_keyed_hash(a)
        t = h['resource_type'] || h['rtype'] || 'user'
        n = h['resource_name'] || h['rname']
        raise ArgumentError.new("no resource_name in #{h.inspect}") unless n
        [ t, n ]
      else
        raise ArgumentError.new("not an assignment #{a.inspect}")
      end }
  end

  def determine_tname(state)

    return 'allocate' if state == 'allocated'
    return state[0..-3] if state[-2..-1] == 'ed'
    "to-#{state}"
  end
end

