
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

    def by_resource(type_or_name, name=:null)

      t, n =
        if name == :null
          [ :null, type_or_name ]
        elsif type_or_name == nil
          [ :null, name ]
        else
          [ type_or_name, name ]
        end

      aq = db[:florist_task_assignments].select(:task_id)
      aq = aq.where(resource_type: t) if t != :null
      aq = aq.where(resource_name: n) if n != :null

      q = self.where(id: aq).all
    end
  end

  alias message data

  def payload

    @payload ||= _data['payload']
  end

  def payload=(h)

    @payload = h
  end

  def assignments

    @assignment_model ||=
      Florist.assignments(db)

    @assignments ||=
      @assignment_model.where(task_id: id).all.each { |a| a.task = self }
  end

  def return(overlay={})

    n = Flor.tstamp

    m = Flor.dup(message)
    m['point'] = 'return'
    m['payload'] = payload

    db[:flor_messages]
      .insert(
        domain: domain,
        exid: exid,
        point: 'return',
        content: Flor::Storage.to_blob(m),
        status: 'created',
        ctime: n,
        mtime: n)
  end

#    def reply_with_error(error)
#      reply(
#        Flor.to_error_message(@message, error))
#    end
  def return_error(err)

fail NotImplementedError
  end
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

