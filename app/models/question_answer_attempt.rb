class QuestionAnswerAttempt
  include Mongoid::Document
  field :answer, type: BSON::Binary
  field :feedback, type: BSON::Binary
  field :fraction, type: Boolean, default: false
  field :attempted, type: Boolean, default: false
  embedded_in :question_attempt, :inverse_of => :question_answer_attempts
  validates_presence_of :answer, :fraction, :attempted

  def as_json(with_key: false)
    if with_key
      super(except: [:_id, :created_at, :updated_at]).merge(id: self.id.to_s)
    else
      super(only: [:answer]).merge(id: self.id.to_s)
    end
  end
end