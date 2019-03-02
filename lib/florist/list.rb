
class Florist::Worklist

  attr_reader :db, :unit

  # Florist::Worklist.new(db)
  # Florist::Worklist.new(flor_unit)
  # Florist::Worklist.new(db, flor_db: flor_db)
  # Florist::Worklist.new(db, flor_db_uri: flor_db)
  #
  def initialize(db_or_unit_or_uri, opts={})

    # TODO track florist db and flor db (for queueing messages back)

    @db, @unit =
      case duu = db_or_unit_or_uri
      when String then [ Sequel.connect(duu, opts[:db_opts] || {}), nil ]
      when Flor::Scheduler then [ duu.storage.db, duu ]
      when Sequel::Database then [ duu, nil ]
      else fail ArgumentError.new("couldn't get db/unit out of #{duu.class}")
      end

    class << @db; attr_accessor :flor_worklist; end
    @db.flor_worklist = self

    @opts =
      get_unit_worklist_conf
         .merge!(Flor.to_string_keyed_hash(opts))

    @controller = get_controller

    @task_table =
      make_model_class(Florist::Task, :florist_tasks)
    @transition_table =
      make_model_class(Florist::Transition, :florist_transitions)
    @assignment_table =
      make_model_class(Florist::Assignment, :florist_assignments)
  end

  def task_table; @task_table; end
  def transition_table; @transition_table; end
  def assignment_table; @assignment_table; end

  def tasks(domain=nil, opts={})

    @controller.may?(:browse_tasks, domain)

    task_table.all
  end

  def transition_to_offered(task_or_id, *as)

    transition_and_or_assign(task_or_id, 'offered', *as)
  end

  def transition_to_allocated(task_or_id, *as)

    transition_and_or_assign(task_or_id, 'allocated', *as)
  end

  alias offer transition_to_offered
  alias allocate transition_to_allocated

  protected

  def make_model_class(parent_class, table_name)

    wl = self

    Class.new(parent_class) do
      self.worklist = wl
      self.dataset = wl.db[table_name]
    end
  end

  def get_unit_worklist_conf

    return {} unless @unit

    @unit.conf
      .inject({}) { |h, (k, v)|
        m = k.match(/\A(?:wli|wol)_(.+)\z/)
        h[m[1]] = v if m
        h }
  end

  def get_controller

    @controller ||=
      if cc = @opts['controller_class']
        cc.new(self)
      elsif ci = @opts['controller']
        ci
      else
        Florist::Controller.new(self)
      end
  end

  def transition_and_or_assign(task_or_task_id, state, *as)

    opts = as.last.is_a?(Hash) ? as.pop : {}
    assignments = extract_assignments(as)

    toti = task_or_task_id
    tid = toti.is_a?(Integer) ? toti : toti.id

    db.transaction do

      now = Flor.tstamp

      s = db[:florist_transitions]
        .select(:id, :state, :domain)
        .where(task_id: tid)
        .reverse(:id)
        .limit(1)
        .first
      sid = s[:id]

      db[:florist_tasks].where(id: tid).update(mtime: now)

      if s[:state] != state
        # TODO create new transition
        sid = db[:florist_transitions]
          .insert(
            task_id: tid,
            state: state,
            description: nil,
            user: opts[:user] || '(florist)',
            domain: s[:domain],
            content: nil,
            ctime: now,
            mtime: now)
      else
        db[:florist_transitions].where(id: sid).update(mtime: now)
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
          fail ArgumentErro.new("no resource_name in #{h.inspect}") unless n
          [ t, n ] }
    else
      fail ArgumentError.new(
        "couldn't figure out assignment list out of #{as.inspect}")
    end
  end

  def queue_message(msg)

    # TODO case where florist db != flor db

    now = Flor.tstamp

    db.transaction do
      #
      # the florist db operations involve 3 florist tables
      # while the flor db operation involves 1
      # use the florist db transaction

      # TODO archive florist rows?

      sq = db[:florist_transitions].where(task_id: id)

      tc = db[:florist_tasks].where(id: id).delete
      ac = db[:florist_assignments].where(transition_id: sq.select(:id)).delete
      sc = sq.delete

      flor_db[:flor_messages]
        .insert(
          domain: domain,
          exid: exid,
          point: 'return',
          content: Flor::Storage.to_blob(msg),
          status: 'created',
          ctime: now,
          mtime: now)
    end
  end
end


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

