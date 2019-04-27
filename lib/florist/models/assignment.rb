
class Florist::Assignment < ::Florist::FloristModel

  def rtype; resource_type; end
  def rname; resource_name; end

  def to_ra; [ rtype, rname ]; end

  def task

    worklist.task_class[id: task_id]
  end

  def transitions

    @flor_model_cache_transitions ||=
      worklist.transition_class
        .where(id: _transition_ids, status: 'active')
        .order(:id)
        .all
  end

  def transition_ids

    transitions.collect(&:id)
  end

  def last_transition

    transitions.last
  end

  def to_h

    h = super
    h[:transition_ids] = transitions.collect(&:id)
    h[:last_transition_id] = h[:transition_ids].last

    h
  end

  protected

  def _transition_ids

    db[:florist_transitions_assignments]
      .where(assignment_id: id, status: 'active')
      .select(:transition_id)
  end
end

