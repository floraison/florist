
Sequel.migration do

  # +------+
  # | task |-1--+
  # +------+    |
  #             | 1 or more
  #      +------+-----+
  #      | transition |-1---+
  #      +------------+     |
  #                         | 0 or more
  #                  +------+-----+
  #                  | assignment |
  #                  +------------+

  up do

    create_table :florist_tasks do

      primary_key :id

      String :domain, null: false
      String :exid, null: false
      String :nid, null: false

      File :content # JSON

      String :ctime, null: false  # creation time
      String :mtime, null: false  # last modification time

      index :domain
      index :exid
      index [ :exid, :nid ]

      String :status, null: true  # could be useful at some point
    end

    create_table :florist_transitions do

      primary_key :id

      Integer :task_id

      String :status, null: false
        # http://www.workflowpatterns.com/patterns/resource/
        # "created"
        # "offered"
        # "allocated"
        # "started"
        # "suspended"
        # "failed"
        # "completed"

      String :description, null: false

      File :content # JSON

      String :ctime, null: false  # creation time
      String :mtime, null: false  # last modification time

      index :task_id
    end

    create_table :florist_assignments do

      primary_key :id

      #Integer task_id, null: false
      Integer transition_id, null: false

      String :resource_type, null: false  # "user", "group", "role", ...
      String :resource_name, null: false  # "bob", "accounting"

      File :content # JSON

      String :description, null: false

      String :ctime, null: false  # creation time
      String :mtime, null: false  # last modification time

      String :status, null: false
        # 'active' or something else

      #index :task_id
      index :transition_id
      index [ :resource_type, :resource_name ]
    end
  end

  down do

    drop_table :florist_tasks
    drop_table :florist_transitions
    drop_table :florist_assignments
  end
end

