
Sequel.migration do

  up do

    create_table :florist_tasks do

      primary_key :id, type: :Integer
      String :domain, null: false
      String :exid, null: false
      String :nid, null: false

      File :content # JSON
        # the task payload and more...

      String :ctime, null: false  # creation time
      String :mtime, null: false  # last modification time
      #String :atime, null: false  # archival time

      String :status, null: false
        # http://www.workflowpatterns.com/patterns/resource/
        # "created"
        # "offered"
        # "allocated"
        # "started"
        # "suspended"
        # "failed"
        # "completed"

      index :domain
      index :exid
      index [ :exid, :nid ]
    end

    create_table :florist_task_assignments do

      primary_key :id, type: :Integer

      Integer :flor_task_id, null: false
      #foreign_key :flor_task_id, :flor_tasks, on_delete: :cascade

      String :type, null: false  # "", "forced", "automatic", "escalated", ...

      String :resource_name, null: false  # "bob", "accounting"
      String :resource_type, null: false  # "user", "group", ...

      File :content # JSON
        # some metadata for this taskee/task pair

      String :ctime, null: false  # creation time
      String :mtime, null: false  # last modification time
      #String :atime, null: false  # archival time

      String :status, null: false
        # "active" / "archived"

      index :flor_task_id
      index :resource_name
      index [ :resource_type, :resource_name ]
    end
  end

  down do

    drop_table :florist_tasks
    drop_table :florist_task_assignments
  end
end

