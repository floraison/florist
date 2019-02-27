
module Florist

  class WorklistTasker < ::Flor::BasicTasker

    def task

      store_task('user', message['tasker'], message)

      []
    end

    protected

    # TODO [ ] @conf['allowed_overrides']
    #          "state", ...

    def get_db

      @uri ||= @conf['db_uri'] || @conf['uri']

      if @uri
        os = @conf['sequel_options'] || @conf['db_options'] || {}
        Sequel.connect(@uri, os)
      else
        @ganger.unit.storage.db
      end
    end

    def opt_or_conf(key, default)

      default # FIXME
    end

    def store_task(rtype, rname, message, opts={})

      now = Flor.tstamp
      exi = message['exid']
      dom = Flor.domain(exi)
      sta = opt_or_conf(:state, 'created')
      rty = opt_or_conf(:resource_type, 'user')
      rna = opt_or_conf(:resource_name, message['tasker'])

      #sta = opts[:task_status] || opts[:status] || 'created'
      #typ = opts[:assignment_type] || opts[:type] || ''
      #ame = opts[:assignment_meta] || opts[:meta]
      #ast = opts[:assignment_status] || 'active'

      ti = nil

      db = get_db

      db.transaction do

        ti = db[:florist_tasks]
          .insert(
            domain: dom,
            exid: exi,
            nid: message['nid'],
            tasker: message['tasker'],
            taskname: message['taskname'],
            attls1: (message['attl'] || []).select { |e| e.is_a?(String) }[1],
            content: Florist.to_blob(message),
            ctime: now,
            mtime: now,
            status: nil)

        si = db[:florist_transitions]
          .insert(
            task_id: ti,
            state: sta,
            description: nil,
            user: '(flor)',
            domain: dom,
            content: nil,
            ctime: now,
            mtime: now)

        db[:florist_assignments]
          .insert(
            transition_id: si,
            resource_type: rty,
            resource_name: rna,
            content: nil,
            description: nil,
            ctime: now,
            mtime: now,
            status: 'active')
      end

      db.disconnect if @uri

      ti
    end
  end
end

