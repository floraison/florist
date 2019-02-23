
module Florist

  class << self

    def tasks(db)

      Class.new(Florist::Task) do
        self.dataset = db[:florist_tasks]
      end
    end

    #def assignments(db)
    #  # TODO
    #end
  end
end

class Florist::Task < ::Flor::FlorModel

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

  def return(overlay={})
  end

  def return_error(err)
  end
#    def reply_with_error(error)
#      reply(
#        Flor.to_error_message(@message, error))
#    end

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
  #
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
end

Flor.add_model(:tasks, Florist, 'florist_')

