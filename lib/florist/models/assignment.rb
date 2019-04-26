
class Florist::Assignment < ::Florist::FloristModel

  def rtype; resource_type; end
  def rname; resource_name; end

  def to_ra; [ rtype, rname ]; end

  def task

    worklist.task_table[id: task_id]
  end

  def transitions

    worklist.transition_table
      .where(id: transition_ids)
      .order(:id)
      .all
  end

  def last_transition

    worklist.transition_table
      .where(id: transition_ids)
      .reverse(:id)
      .first
  end

  def to_h

    h = super
    h[:transition_ids] = transitions.collect(&:id)
    h[:last_transition_id] = h[:transition_ids].last

    h
  end

  protected

  def transition_ids

    db[:florist_transitions_assignments]
      .where(assignment_id: id, status: 'active')
      .select(:transition_id)
  end
end

