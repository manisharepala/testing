class QuestionAttempt
  include Mongoid::Document
  # field :question_id, type: String
  # field :qtype, type: String
  field :correct, type: Boolean
  field :start_time, type: DateTime
  field :end_time, type: DateTime
  field :time_taken, type: Integer
  field :marks, type: Float
  field :question_answer_attempts, type: Array

  embeds_one :question
  embeds_many :question_answer_attempts, cascade_callbacks: true

end
