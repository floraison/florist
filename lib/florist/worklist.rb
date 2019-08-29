
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

  alias rtype resource_type
  alias rname resource_name

  alias db florist_db

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
    @opts = get_unit_worklist_conf.merge!(opts)

    fail ArgumentError.new("missing a florist database") \
      unless @florist_db

    class << @florist_db; attr_accessor :flor_worklist; end
    @florist_db.flor_worklist = self

    @resource_type = opts['resource_type'] || opts['rtype'] || 'user'
    @resource_name = opts['resource_name'] || opts['rname'] || '(florist)'
    @resource_domain = opts['resource_domain'] || opts['rdomain'] || ''

    @controller = get_controller

    @tasks = make_model_class(Florist::Task, :florist_tasks)
    @transitions = make_model_class(Florist::Transition, :florist_transitions)
    @assignments = make_model_class(Florist::Assignment, :florist_assignments)

    @transitions_assignments =
      make_model_class(
        Florist::TransitionAssignment,
        :florist_transitions_assignments)

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

  def return(msg)

    if unit

      unit.return(msg)

    elsif flor_db

      flor_db[:flor_messages]
        .insert(
          domain: domain,
          exid: exid,
          point: 'return',
          content: Flor.to_blob(msg),
          status: 'created',
          ctime: now,
          mtime: now)

    else

      nil
    end
  end

  def dump(io=nil, opts=nil, &block)
# FIXME what if florist_db != flor_db, transactions?

    io, opts = nil, io if io.is_a?(Hash)
    opts ||= {}

    d =
      lambda do |h|

        florist_db.transaction do

          exis, doms, sdms =
            extract_dump_and_load_filters(opts)

          tids = florist_db[:florist_tasks].select(:id)

          tids = tids.where(
            exid: exis) if exis
          tids = tids.where {
            Sequel.|(*doms
              .inject([]) { |a, d|
                a.concat([
                  { domain: d },
                  Sequel.like(:domain, d + '.%') ]) }) } if doms
          tids = tids.where(
            domain: sdms) if sdms

          h[:tasks] =
            tasks.where(id: tids).collect(&:to_dump_h)
          h[:transitions] =
            transitions.where(task_id: tids).collect(&:to_dump_h)
          h[:transitions_assignments] =
            @transitions_assignments.where(task_id: tids).collect(&:to_dump_h)
          h[:assignments] =
            assignments.where(task_id: tids).collect(&:to_dump_h)

          h[:timestamp] ||= Flor.tstamp
        end

        h
      end

    return Flor.dump(flor_db, io, opts, &d) if opts[:flor]

    hash = d.call({})

    return hash if opts[:hash] || opts[:h]

    o = io ? io : StringIO.new

    JSON.dump(hash, o)

    io ? io : o.string
  end

  def load(string_or_io, opts={}, &block)
# FIXME what if florist_db != flor_db, transactions?

    d =
      lambda do |h, counts|

        florist_db.transaction do

          task_id_map = {}
          transition_id_map = {}
          assignment_id_map = {}

          h['tasks'].each do |t|
            task_id_map[t['id']] = tasks.insert_from_h(t)
          end
          h['transitions'].each do |s|
            s['task_id'] = task_id_map[s['task_id']]
            transition_id_map[s['id']] = transitions.insert_from_h(s)
          end
          h['assignments'].each do |a|
            a['task_id'] = task_id_map[a['task_id']]
            transition_id_map[a['id']] = assignments.insert_from_h(a)
          end
          h['transitions_assignments'].each do |sa|
            sa['task_id'] = task_id_map[sa['task_id']]
            sa['transition_id'] = transition_id_map[sa['transition_id']]
            sa['assignment_id'] = assignment_id_map[sa['assignment_id']]
            transitions_assignments.insert_from_h(sa)
          end
        end

        counts[:tasks] = h['tasks'].size
        counts[:transitions] = h['transitions'].size
        counts[:transitions_assignments] = h['transitions_assignments'].size
        counts[:assignments] = h['assignments'].size

        counts
      end

    if opts[:flor]
      Flor.load(flor_db, string_or_io, opts, &d)
    else
      d.call({}, {})
    end
  end

  def migrate(to=nil, from=nil, opts=nil)

    Florist.migrate(to, from, @opts.merge(opts || {}))
  end

  protected

  def extract_dump_and_load_filters(opts)

    o = lambda { |k| v = opts[k] || opts["#{k}s".to_sym]; v ? Array(v) : nil }

    [ o[:exid], o[:domain], o[:strict_domain] || o[:sdomain] ]
  end

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
      florist_db || flor_db || (unit && unit.storage.db),
      Flor.to_string_keyed_hash(opts) ]
  end

  def make_model_class(parent_class, table_name)

    wl = self

    Class.new(parent_class) do
      self.worklist = wl
      self.dataset = wl.florist_db[table_name]
    end
  end

  def get_unit_worklist_conf

    return {} unless @unit

    @unit.conf
      .inject({}) { |h, (k, v)|
        m = k.match(/\A(?:wli|wol|fst)_(.+)\z/)
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
end

