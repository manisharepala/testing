class QuizAttempt
  include Mongoid::Document
  field :publish_id, type: Integer
  field :user_id, type: Integer
  field :quiz_id, type: String
  field :attempt, type: Integer
  field :marks, type: Float
  field :start_time, type: DateTime
  field :end_time, type: DateTime

  embeds_many :question_attempts
end
