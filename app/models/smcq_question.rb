class SmcqQuestion < ObjectiveQuestion
  validate :unique_answer

  protected
  def abstract_class
    false
  end

  def unique_answer
    correct_answers = question_answers.where(fraction: true).count
    errors.add :question_answers, 'Multiple Answers' unless correct_answers==1
  end
end
