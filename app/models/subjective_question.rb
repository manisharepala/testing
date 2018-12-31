class SubjectiveQuestion < Question
  # include Mongoid::Document
  field :answer_lines, type: Integer
  protected
  def abstract_class
    false
    # errors.add(:qtype, 'Invalid qtype')
  end
end
