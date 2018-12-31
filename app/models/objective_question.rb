class ObjectiveQuestion < Question
  # include Mongoid::Document
  embeds_many :question_answers, cascade_callbacks: true

  validates_presence_of :question_answers
  accepts_nested_attributes_for :question_answers

  validate :answer_present

  def as_json(with_key: false)
    common_data = common_data_json(with_key: with_key)
    options = self.question_answers.map{|a| a.as_json(with_key: with_key)}
    common_data.merge(
      options: options
    )
  end

  protected
  def abstract_class
    errors.add(:qtype, 'Invalid qtype')
  end

  def answer_present
    correct_answers = question_answers.where(fraction: true).count
    errors.add :question_answers, 'Multiple Answers' if correct_answers==0
  end
end
