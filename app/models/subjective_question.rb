class SubjectiveQuestion < Question
  # include Mongoid::Document
  field :answer_lines, type: Integer

  def as_json(with_key: false,with_language_support:false)
    common_data_json(with_key: with_key,with_language_support:false)
  end

  protected
  def abstract_class
    false
    # errors.add(:qtype, 'Invalid qtype')
  end
end
