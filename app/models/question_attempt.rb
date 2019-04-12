class QuestionAttempt
  include Mongoid::Document
  field :question_json, type: BSON::Binary #from quiz_json
  field :correct, type: Boolean
  field :start_time, type: DateTime
  field :end_time, type: DateTime
  field :time_taken, type: Integer
  field :marks_scored, type: Float

  embeds_many :question_answer_attempts, cascade_callbacks: true
  embeds_many :question_fill_blank_attempts, cascade_callbacks: true
  embedded_in :quiz_attempt, :inverse_of => :question_attempts

end
