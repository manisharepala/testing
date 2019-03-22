class QuestionFillBlank
  include Mongoid::Document
  field :answer, type: Array
  field :case_sensitive, type: Boolean, default: false
  validates_presence_of :answer
  # before_create :remove_extra_spaces
  embedded_in :fib_question

  def as_json(with_key: false,with_language_support:false)
    if with_key
      {
        id: self.id.to_s,
        answer: answer, case_sensitive: case_sensitive
      }
    else
      {id: self.id.to_s, case_sensitive: case_sensitive}
    end
  end

  private
  def remove_extra_spaces
    self.answer.strip!
  end
end
