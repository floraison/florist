
module Florist

  class << self

    def tasks(db)

      Class.new(Florist::Task) do
        self.dataset = db[:florist_tasks]
      end
    end

    def assignments(db)

      Class.new(Florist::TaskAssignment) do
        self.dataset = db[:florist_task_assignments]
      end
    end
  end
end

class Florist::Task < ::Flor::FlorModel

  # create_table :florist_tasks do
  #   primary_key :id
  #   String :domain, null: false
  #   String :exid, null: false
  #   String :nid, null: false
  #   File :content # JSON
  #   String :ctime, null: false  # creation time
  #   String :mtime, null: false  # last modification time
  #
  #   String :status, null: false
  #     # http://www.workflowpatterns.com/patterns/resource/
  #     # "created"
  #     # "offered"
  #     # "allocated"
  #     # "started"
  #     # "suspended"
  #     # "failed"
  #     # "completed"
  #
  #   index :domain
  #   index :exid
  #   index [ :exid, :nid ]
  # end

  class << self

    def by_resource(type_or_name, name=nil)

      t, n =
        if name
          [ type_or_name, name ]
        else
          [ nil, type_or_name ]
        end

      aq = db[:florist_task_assignments].select(:task_id)
      aq = aq.where(resource_type: t) if t
      aq = aq.where(resource_name: n) if n

      q = self.where(id: aq).all
    end

    alias by_assignment by_resource
    alias assigned_to by_resource
  end

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

  def assignments

    @assignment_model ||=
      Florist.assignments(db)

    @assignments ||=
      @assignment_model.where(task_id: id).all.each { |a| a.task = self }
  end

  def assignment; assignments.first; end

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

  def return(overlay={})

    n = Flor.tstamp

    m = Flor.dup(message)
    m['point'] = 'return'
    m['payload'] = payload

    db.transaction do

      tc = db[:florist_tasks]
        .where(id: id).delete
      tac = db[:florist_task_assignments]
        .where(task_id: id).delete

      db[:flor_messages]
        .insert(
          domain: domain,
          exid: exid,
          point: 'return',
          content: Flor::Storage.to_blob(m),
          status: 'created',
          ctime: n,
          mtime: n)

      tc
    end
  end

#    def reply_with_error(error)
#      reply(
#        Flor.to_error_message(@message, error))
#    end
  def return_error(err)

fail NotImplementedError
  end

#  def assign(resource_type, resource_name)
#
#    db[:flor_task_assignments]
#      .insert(
#  end
end

class Florist::TaskAssignment < ::Flor::FlorModel

  # create_table :florist_task_assignments do
  #   primary_key :id
  #   Integer :task_id, null: false
  #   #foreign_key :task_id, :flor_tasks, on_delete: :cascade
  #   String :type, null: false  # "", "forced", "automatic", "escalated", ...
  #   String :resource_name, null: false  # "bob", "accounting"
  #   String :resource_type, null: false  # "user", "group", ...
  #   File :content # JSON
  #   String :ctime, null: false  # creation time
  #   String :mtime, null: false  # last modification time
  #   String :status, null: false  # "active" / "archived"
  #
  #   index :task_id
  #   index :resource_name
  #   index [ :resource_type, :resource_name ]
  # end

  attr_accessor :task
end

Flor.add_model(:tasks, Florist, 'florist_')
Flor.add_model(:task_assignments, Florist, 'florist_')

