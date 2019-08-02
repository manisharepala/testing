class QuizAttempt
  include Mongoid::Document
  field :publish_id, type: Integer
  field :user_id, type: Integer
  field :book_guid, type: String
  field :quiz_guid, type: String
  field :attempt_no, type: Integer
  field :marks_scored, type: Float
  field :total_marks, type: Float
  field :start_time, type: Integer
  field :end_time, type: Integer
  field :active_duration, type: Integer

  embeds_many :question_attempts
  embeds_many :quiz_section_attempts
  accepts_nested_attributes_for :question_attempts
  accepts_nested_attributes_for :quiz_section_attempts
end
