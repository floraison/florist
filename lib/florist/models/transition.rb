
class Florist::Transition < ::Florist::FloristModel

  def assignments

    @flor_model_cache_assignments ||=
      worklist.assignments
        .where(id: _assignment_ids, status: 'active')
        .order(:id)
        .all
  end

  def assignment_ids

    assignments.collect(&:id)
  end

  def assignment

    assignments.first
  end

  def to_h

    h = super()
    h[:assignments] = assignments.collect(&:id)

    h
  end

  protected

  def _assignment_ids

    db[:florist_transitions_assignments]
      .where(transition_id: id, status: 'active')
      .select(:assignment_id)
  end
end

