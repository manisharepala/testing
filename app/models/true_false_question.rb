class TrueFalseQuestion < ObjectiveQuestion
  # include Mongoid::Document
  validate :unique_answer
  validate :number_of_options

  protected
  def abstract_class
    false
  end

  def unique_answer
    correct_answers = question_answers.where(fraction: true).count
    errors.add :question_answers, 'Multiple Answers' unless correct_answers==1
  end

  def number_of_options
    errors.add :question_answers, 'Only two options are allowed' unless question_answers.length==2
  end
end
