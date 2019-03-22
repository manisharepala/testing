class PassageQuestion < Question
  field :question_guids, type: Array, default: []

  def as_json(with_key: false,with_language_support:false)
    common_data = common_data_json(with_key: with_key,with_language_support:with_language_support)
    questions = self.question_guids.map{|a| (Question.where(guid:a)[0]).as_json(with_key: with_key,with_language_support:with_language_support)}
    final_data = common_data.merge(
        questions: questions
    )
    JSON.parse(final_data.to_json)
  end

  protected
  def abstract_class
    false
  end

end
