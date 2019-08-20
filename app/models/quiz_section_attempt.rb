class QuizSectionAttempt
  include Mongoid::Document
  field :question_ids, type: Array, default: []
  field :marks_scored, type: Float
  field :total_marks, type: Float
  field :active_duration, type: Integer
  field :quiz_section_id, type: String

  embedded_in :quiz_attempt, :inverse_of => :quiz_section_attempts

end
