class QuestionAttempt
  include Mongoid::Document
  field :question_json, type: BSON::Binary #from quiz_json
  field :correct, type: Boolean
  field :start_time, type: Integer
  field :end_time, type: Integer
  field :time_taken, type: Integer
  field :marks_scored, type: Float

  embeds_many :question_answer_attempts, cascade_callbacks: true
  embeds_many :question_fill_blank_attempts, cascade_callbacks: true
  embedded_in :quiz_attempt, :inverse_of => :question_attempts

  accepts_nested_attributes_for :question_answer_attempts
  accepts_nested_attributes_for :question_fill_blank_attempts
end
