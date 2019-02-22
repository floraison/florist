
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

