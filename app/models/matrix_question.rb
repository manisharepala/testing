class MatrixQuestion < Question

  embeds_many :question_statements, cascade_callbacks: true
  embeds_many :question_answers, cascade_callbacks: true

  validates_presence_of :question_statements,:question_answers
  accepts_nested_attributes_for :question_statements,:question_answers


  def as_json(with_key: false,with_language_support:false)
    common_data = common_data_json(with_key: with_key,with_language_support:with_language_support)
    match_statements = self.question_statements.map{|a| a.as_json(with_key: with_key,with_language_support:with_language_support)}
    match_options = self.question_answers.map{|a| a.as_json(with_key: with_key,with_language_support:with_language_support)}
    match_options.each do |hash|
      hash.except!('fraction')
    end
    common_data.merge(
        match_statements:match_statements,
        match_options: match_options
    )
  end

  protected
  def abstract_class
    false
  end

end
