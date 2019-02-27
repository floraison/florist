
class Florist::Worklist

  attr_reader :db, :unit

  def initialize(db_or_unit_or_uri, opts={})

    @db, @unit =
      case duu = db_or_unit_or_uri
      when String then [ Sequel.connect(duu, opts[:db_opts] || {}), nil ]
      when Flor::Scheduler then [ duu.storage.db, duu ]
      when Sequel::Database then [ duu, nil ]
      else fail ArgumentError.new("couldn't get db/unit out of #{duu.class}")
      end

    class << @db; attr_accessor :flor_worklist; end
    @db.flor_worklist = self

    @opts = opts

    @controller = get_controller

    db = @db
      #
    @task_class =
      Class.new(Florist::Task) { self.dataset = db[:florist_tasks] }
  end

  def tasks(domain=nil)

    @controller.may?(:browse_tasks, domain)

    @task_class.all
  end

  protected

  def get_controller

    Florist::Controller.new
  end
end

class Florist::Controller

  def may?(right, domain)

    true
  end
end

