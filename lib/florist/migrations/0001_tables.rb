
Sequel.migration do

  # +------+  * a task is in the state of its last transition
  # | task |
  # +--+---+
  #    |
  # +--+---------+  * a transition may have 0 or more assignments
  # | transition |
  # +--+---------+
  #    |
  # +--+--------------------+
  # | transition-assignment |
  # +--+--------------------+
  #    |
  # +--+---------+  * an assignment is linked to 1 or more transitions
  # | assignment |
  # +------------+

  up do

    create_table :florist_tasks do

      primary_key :id

      String :domain, null: false
      String :exid, null: false
      String :nid, null: false

      String :tasker, null: false   # msg['tasker']
      String :taskname, null: true  # msg['taskname']
      String :attls1, null: true    # (msg['attl'] || []).select(:string?)[1]

      File :content # JSON
        # contains the "task" message as received

      String :ctime, null: false  # creation time
      String :mtime, null: false  # last modification time

      String :status, null: false  # 'active' or something else

      index :domain
      index :exid
      index [ :exid, :nid ]
    end

    create_table :florist_transitions do

      primary_key :id

      Integer :task_id, null: false

      String :state, null: false
        #
        # http://www.workflowpatterns.com/patterns/resource/
        #
        # "created"
        # "offered"
        # "allocated"
        # "started"
        # "suspended"
        # "failed"
        # "completed"
        #
        # "archived"

      String :name, null: false
        #
        # http://www.workflowpatterns.com/patterns/resource/#fig6
        #
        # "create", "offer", "allocate", "start", "fail"
        #   and also
        # "suspend", "resume", "escalate", "delegate", "deallocate",
        # "skip"

      String :description

      String :user    # who ordered the transition
      String :domain  # level of authority for the transition[er]

      File :content # JSON
        # contains the updated payload (not the whole message) or null

      String :ctime, null: false  # creation time
      String :mtime, null: false  # last modification time

      String :status, null: false  # "active" or something else

      index :task_id
    end

    create_table :florist_transitions_assignments do

      Integer :task_id, null: false

      Integer :transition_id, null: false
      Integer :assignment_id, null: false

      String :ctime, null: false  # creation time
      String :mtime, null: false  # last modification time

      String :status, null: false  # "active" or something else

      unique [ :task_id, :transition_id, :assignment_id ]

      index :task_id
      index :assignment_id
    end

    create_table :florist_assignments do

      primary_key :id

      Integer :task_id, null: false

      String :resource_type, null: false  # "user", "group", "role", ...
      String :resource_name, null: false  # "bob", "accounting"

      File :content # JSON

      String :description

      String :ctime, null: false  # creation time, Flor.tstamp
      String :mtime, null: false  # last modification time, Flor.tstamp

      String :status, null: false  # "active" or something else

      unique [ :task_id, :resource_type, :resource_name ]

      index :task_id
      index [ :resource_type, :resource_name ]
    end
  end

  down do

    drop_table :florist_tasks
    drop_table :florist_transitions
    drop_table :florist_transitions_assignments
    drop_table :florist_assignments
  end
end

