class QuestionAnswerAttempt
  include Mongoid::Document

  field :question_answer_json, type: BSON::Binary #from quiz_json
  field :is_selected, type: Boolean, default: false
  field :is_correct, type: Boolean, default: false

  embedded_in :question_attempt, :inverse_of => :question_answer_attempts

end
