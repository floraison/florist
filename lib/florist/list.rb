
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

    @task_class =
      make_model_class(Florist::Task, :florist_tasks)
    #@transition_class =
    #  make_model_class(Florist::Transition, :florist_transitions)
    #@assignment_class =
    #  make_model_class(Florist::Assignment, :florist_assingments)
  end

  def tasks(domain=nil)

    @controller.may?(:browse_tasks, domain)

    @task_class.all
  end

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

