
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

      n = Time.now

      @ganger.unit.storage.transync do

        ti = @ganger.unit.storage.db[:florist_tasks].insert(
          domain: Flor.domain(exid),
          exid: message['exid'],
          nid: message['nid'],
          content: Flor::Storage.to_blob(message),
          ctime: n,
          mtime: n,
          status: 'created')

        @ganger.unit.storage.db[:florist_task_assignments].insert(
          task_id: ti,
          type: '',
          resource_name: message['tasker'],
          resource_type: 'user',
          content: nil,
          ctime: n,
          mtime: n,
          status: 'active')
      end

      []
#rescue => err
#p err
    end
  end

  class RoleTasker < Tasker
  end
end

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

