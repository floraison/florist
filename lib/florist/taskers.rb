
module Florist

  class Tasker < ::Flor::BasicTasker

    include Florist::Storing

    def task
    end

    def detask
    end

    protected
  end

  class UserTasker < Tasker

    def task

      store_task(message['tasker'], 'user', message)

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

