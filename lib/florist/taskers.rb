
module Florist

  class Tasker < ::Flor::BasicTasker

    protected

    def db

      @db ||=
        if db = @conf['db'] # FIXME, does not go through tconf serialization!
          db
        elsif uri = @conf['db_uri']
          os = @conf['sequel_options'] || @conf['db_options'] || {}
          Sequel.connect(uri, os)
        else
          @ganger.unit.storage.db
        end
    end

    def store_task(rname, rtype, message, opts={})

      now = Time.now
      sta = opts[:task_status] || opts[:status] || 'created'
      typ = opts[:assignment_type] || opts[:type] || ''
      ame = opts[:assignment_meta] || opts[:meta]
      ast = opts[:assignment_status] || 'active'

      db.transaction do

        ti = db[:florist_tasks]
          .insert(
            domain: Flor.domain(exid),
            exid: message['exid'],
            nid: message['nid'],
            content: Florist.to_blob(message),
            ctime: now,
            mtime: now,
            status: sta)

        db[:florist_task_assignments]
          .insert(
            task_id: ti,
            type: typ,
            resource_name: rname,
            resource_type: rtype,
            content: Florist.to_blob(ame),
            ctime: now,
            mtime: now,
            status: ast)

        ti
      end
    end
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

