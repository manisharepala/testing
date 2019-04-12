class QuestionFillBlankAttempt
  include Mongoid::Document

  field :question_fill_blank_json, type: BSON::Binary #from quiz_json
  field :attempted_answer, type: Array
  field :is_correct, type: Boolean, default: false

  embedded_in :question_attempt, :inverse_of => :question_fill_blank_attempts

end
