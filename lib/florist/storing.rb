
module Florist::Storing

  protected

  def storage

    case
    when @ganger then @ganger.unit.storage
    when @unit then @unit.storage
    when @storage then @storage
    end
  end

  def store_task(rname, rtype, message, opts={})

    now = Time.now
    typ = opts[:type] || ''
    sta = opts[:status] || 'created'
    ame = opts[:assignment_meta]

    storage.transync do

      ti = storage.db[:florist_tasks].insert(
        domain: Flor.domain(exid),
        exid: message['exid'],
        nid: message['nid'],
        content: to_blob(message),
        ctime: now,
        mtime: now,
        status: sta)

      storage.db[:florist_task_assignments].insert(
        task_id: ti,
        type: typ,
        resource_name: rname,
        resource_type: rtype,
        content: to_blob(ame),
        ctime: now,
        mtime: now,
        status: 'active')

      ti
    end
  end

  def unstore_task
  end

  def assign_task
  end

  def to_blob(o)

    o ? Flor::Storage.to_blob(message) : nil
  end
end

