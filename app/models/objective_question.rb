class ObjectiveQuestion < Question
  # include Mongoid::Document
  embeds_many :question_answers, cascade_callbacks: true

  validates_presence_of :question_answers
  accepts_nested_attributes_for :question_answers

  validate :answer_present

  def as_json(with_key: false,with_language_support:false)
    common_data = common_data_json(with_key: with_key,with_language_support:with_language_support)
    options_data = []
    question_answers.each do |qa|
      d = {}
      d['id'] = qa.id.to_s
      #d['fraction'] = qa.fraction
      if with_language_support
        d['option_text'] = {}
        d['option_text']['english'] = qa.answer_english
        d['option_text']['hindi'] = qa.answer_hindi
      else
        d['option_text'] = qa.answer_english
      end

      options_data << d
    end
    final_data = common_data.merge(
        options: options_data,
        answers: ([self.question_answers.map{|a| a._id.to_s if a.fraction == true} - [nil]]),
        blanks: []
    )
    JSON.parse(final_data.to_json)
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
