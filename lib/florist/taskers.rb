
module Florist

  class Tasker < ::Flor::BasicTasker
    include Florist::Storing
  end

  class UserTasker < Tasker

    def task

      store_task(message['tasker'], 'user', message)

      []
    end
  end

  class GroupTasker < Tasker

    def task

      store_task(message['tasker'], 'group', message)

      []
    end
  end
end

