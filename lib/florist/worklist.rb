
class Florist::Worklist

  attr_reader :florist_db  # the Sequel florist database
  attr_reader :flor_db     # the Sequel flor database (may be nil)
  attr_reader :unit        # the flor unit/scheduler (may be nil)

  attr_reader :opts

  attr_reader :resource_type
  attr_reader :resource_name

  attr_reader :resource_domain

  attr_reader :controller

  attr_reader :tasks, :transitions, :assignments

  # Florist::Worklist.new(flor_unit/*, opts*/)
  # Florist::Worklist.new(flor_unit, florist_db/*, opts*/)
  # Florist::Worklist.new(flor_unit, florist_db_uri/*, opts*/)
  # Florist::Worklist.new(flor_db, florist_db/*, opts*/)
  # Florist::Worklist.new(flor_unit, florist_db/*, opts*/)
  # Florist::Worklist.new(flor_db_uri, florist_db/*, opts*/)
  # ...
  #
  def initialize(*args)

    @unit, @flor_db, @florist_db, opts = sort_arguments(args)

    class << @florist_db; attr_accessor :flor_worklist; end
    @florist_db.flor_worklist = self

    @opts =
      get_unit_worklist_conf
         .merge!(Flor.to_string_keyed_hash(opts))

    @resource_type = opts[:resource_type] || opts[:rtype] || 'user'
    @resource_name = opts[:resource_name] || opts[:rname] || '(florist)'
    @resource_domain = opts[:resource_domain] || opts[:rdomain] || '(florist)'

    @controller = get_controller

    @tasks = make_model_class(Florist::Task, :florist_tasks)
    @transitions = make_model_class(Florist::Transition, :florist_transitions)
    @assignments = make_model_class(Florist::Assignment, :florist_assignments)

#    @tasks = @tasks
#      .where(Sequel.like(:domain, @domain.split('.').join('.') + '.%')) \
#        unless @domain.empty?
  end

  def task_dataset
    @florist_db[:florist_tasks]
  end
  def transition_dataset
    @florist_db[:florist_transitions]
  end
  def transition_assignment_dataset
    @florist_db[:florist_transitions_assignments]
  end
  def assignment_dataset
    @florist_db[:florist_assignments]
  end
    #
  alias task_ds task_dataset
  alias transition_ds transition_dataset
  alias transition_assignment_ds transition_assignment_dataset
  alias assignment_ds assignment_dataset

  def resource_type_and_name; "#{@resource_type}|#{@resource_name}"; end
  alias r_type_and_name resource_type_and_name

#  def list_tasks(domain=nil, opts={})
#
#    @controller.may?(:browse_tasks, domain)
#
#    task_class.all
#      # TODO filter by domain
#  end
  #
  # attack via the assignments

#  def task_page(opts={})
#
#    @controller.filter(opts)
#  end

  protected

  def sort_arguments(args)

    unit, flor_db, florist_db = nil
    opts = {}

    args.each do |arg|

      arg = Sequel.connect(arg, opts[:db_opts] || {}) if arg.is_a?(String)

      case arg
      when Hash
        opts.merge!(arg)
      when Flor::Scheduler
        unit = arg
      when Sequel::Database
        if arg.tables.include?(:flor_executions)
          flor_db = arg
        else
          florist_db = arg
        end
      else
        fail ArgumentError.new("couldn't get db/unit out of #{arg.class}")
      end
    end

    [ unit,
      flor_db,
      florist_db || flor_db || unit.storage.db,
      opts ]
  end

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
          content: Flor.to_blob(msg),
          status: 'created',
          ctime: now,
          mtime: now)
    end
  end
end

