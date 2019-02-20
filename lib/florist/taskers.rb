
module Florist

  class Tasker < ::Flor::BasicTasker

    def task
    end

    def detask
    end

    protected
  end

  class UserTasker < Tasker

    def task
pp message
      []
    end
  end

  class RoleTasker < Tasker
  end
end

#    create_table :florist_tasks do
#
#      primary_key :id, type: :Integer
#      String :domain, null: false
#      String :exid, null: false
#      String :nid, null: false
#
#      File :content # JSON
#        # the task payload and more...
#
#      String :ctime, null: false  # creation time
#      String :mtime, null: false  # last modification time
#      #String :atime, null: false  # archival time
#
#      String :status, null: false
#        # http://www.workflowpatterns.com/patterns/resource/
#        # "created"
#        # "offered"
#        # "allocated"
#        # "started"
#        # "suspended"
#        # "failed"
#        # "completed"
#    end

#    create_table :florist_task_assignments do
#
#      primary_key :id, type: :Integer
#
#      Integer :flor_task_id, null: false
#      #foreign_key :flor_task_id, :flor_tasks, on_delete: :cascade
#
#      String :type, null: false  # "", "forced", "automatic", "escalated", ...
#
#      String :resource_name, null: false  # "bob", "accounting"
#      String :resource_type, null: false  # "user", "group", ...
#
#      File :content # JSON
#        # some metadata for this taskee/task pair
#
#      String :ctime, null: false  # creation time
#      String :mtime, null: false  # last modification time
#      #String :atime, null: false  # archival time
#
#      String :status, null: false
#        # "active" / "archived"
#    end

#  class BasicTasker
#
#    attr_reader :ganger, :conf, :message
#
#    def initialize(ganger, conf, message)
#      ...
#    end
#
#    protected
#
#    def exid; @message['exid']; end
#    def nid; @message['nid']; end
#
#    def payload; @message['payload']; end
#    alias fields payload
#
#    def attd; @message['attd']; end
#    def attl; @message['attl']; end
#
#    def tasker; @message['tasker']; end
#    def taskname; @message['taskname']; end
#    alias task_name taskname
#
#    def vars; @message['vars']; end
#
#    def execution; @ganger.unit.execution(exid); end
#
#    def reply(message=@message, force=false)
#      @ganger.return(message) if force || @ganger
#      [] # very important, return no further messages
#    end
#
#    def reply_with_error(error)
#      reply(
#        Flor.to_error_message(@message, error))
#    end
#  end

