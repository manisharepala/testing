class SubjectiveQuestion < Question
  # include Mongoid::Document
  field :answer_lines, type: Integer

  def as_json(with_key: false)
    common_data = common_data_json(with_key: with_key)

    common_data.merge(
        options: [],
        answers: [self.generalfeedback],
        blanks: []
    )
  end

  protected
  def abstract_class
    false
    # errors.add(:qtype, 'Invalid qtype')
  end
end
