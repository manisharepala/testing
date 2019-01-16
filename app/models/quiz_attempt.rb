class QuizAttempt
  include Mongoid::Document
  field :publish_id, type: Integer
  field :user_id, type: Integer
  field :book_id, type: String
  field :quiz_id, type: String
  field :attempt, type: Integer
  field :marks_scored, type: Float
  field :total_marks, type: Float
  field :start_time, type: DateTime
  field :end_time, type: DateTime
  field :active_duration, type: Integer

  embeds_many :question_attempts
end
