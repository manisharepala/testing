class QuizAttempt
  include Mongoid::Document
  include Mongoid::Timestamps

  field :quiz_attempt_data_id, type: String
  field :published_id, type: String
  field :group_id, type: Integer
  field :user_id, type: Integer
  field :book_guid, type: String
  field :quiz_guid, type: String
  field :attempt_no, type: Integer
  field :marks_scored, type: Float
  field :total_marks, type: Float
  field :start_time, type: Integer
  field :end_time, type: Integer
  field :active_duration, type: Integer

  field :total, type: Integer
  field :attempted, type: Integer
  field :un_attempted, type: Integer
  field :correct, type: Integer
  field :in_correct, type: Integer
  field :skipped, type: Integer

  index({:quiz_guid=>1,:user_id => 1})
  index({:quiz_guid=>1})
  index({:quiz_guid=>1,:user_id => 1,:quiz_attempt_data_id=>1})
  index({:quiz_guid=>1,"quiz_section_attempts.quiz_section_id"=>1})
  index({:marks_scored=>1})
  index({:quiz_guid=>1,:attempt_no=>1})
  index({"quiz_section_attempts.section_id"=>1})
  index({:quiz_guid=>1,:attempt_no=>1,:"question_attempts.attempt_type"=>1,"question_attempts.question_id"=>1 })
  index({:quiz_guid=>1,:attempt_no=>1,"quiz_section_attempts.quiz_section_id"=>1})


  embeds_many :question_attempts
  embeds_many :quiz_section_attempts
  accepts_nested_attributes_for :question_attempts
  accepts_nested_attributes_for :quiz_section_attempts







end
