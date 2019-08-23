class QuizSectionAttempt
  include Mongoid::Document
  field :question_ids, type: Array, default: []
  field :marks_scored, type: Float
  field :total_marks, type: Float
  field :active_duration, type: Integer
  field :quiz_section_id, type: String
  field :quiz_section_name, type: String

  field :total, type: Integer
  field :attempted, type: Integer
  field :un_attempted, type: Integer
  field :correct, type: Integer
  field :in_correct, type: Integer
  field :skipped, type: Integer

  embedded_in :quiz_attempt, :inverse_of => :quiz_section_attempts

end
