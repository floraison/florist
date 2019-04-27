
class Florist::Transition < ::Florist::FloristModel

  def assignments

    worklist.assignment_class
      .where(id: assignment_ids, status: 'active')
      .order(:id)
      .all
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

  def assignment_ids

    db[:florist_transitions_assignments]
      .where(transition_id: id, status: 'active')
      .select(:assignment_id)
  end
end

