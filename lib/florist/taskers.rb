
module Florist

  class WorklistTasker < ::Flor::BasicTasker

    def task

      store_task('user', message['tasker'], message)

      []
    end

    protected

    def get_db

      @uri ||= @conf['db_uri'] || @conf['uri']

      if @uri
        os = @conf['sequel_options'] || @conf['db_options'] || {}
        Sequel.connect(@uri, os)
      else
        @ganger.unit.storage.db
      end
    end

    def overrides

      @overrides ||=
        { rtype: 'resource_type', rname: 'resource_name' }
          .inject(
            @conf['overrides'] || []
          ) { |a, (k, v)|
            k = k.to_s
            a << k << v if a.include?(k) || a.include?(v)
            a }
          #.uniq
    end

    def opt_or_conf(*keys)#, default)

      default = keys.pop
      ks = keys.collect(&:to_s)

      ad = @message['attd']

      ks.each do |k|

        return ad[k] if overrides.include?(k) && ad.has_key?(k)
        return @conf[k] if @conf.has_key?(k)
      end

      default
    end

    def store_task(rtype, rname, message, opts={})

      now = Flor.tstamp
      exi = message['exid']
      dom = Flor.domain(exi)
      rty = opt_or_conf(:resource_type, :rtype, nil)
      rna = rty ? opt_or_conf(:resource_name, :rname, message['tasker']) : nil
      sta = opt_or_conf(:state, rty ? 'offered' : 'created')

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
            status: 'active'
        ) if rty
      end

      db.disconnect if @uri

      ti
    end
  end
end

