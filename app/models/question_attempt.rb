class QuestionAttempt
  include Mongoid::Document
  field :question_id, type: String
  field :qtype, type: String
  field :correct, type: Boolean
  field :time_taken, type: Integer
  field :start_time, type: DateTime
  field :end_time, type: DateTime
  field :marks, type: Float
  field :question_answer_ids, type: Array
  field :answers, type: Array
end
