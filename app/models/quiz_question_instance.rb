class QuizQuestionInstance
  include Mongoid::Document
  include Mongoid::Timestamps

  field :marks, type: Float
  field :penalty, type: Float

  belongs_to :question
  embedded_in :question_instances, polymorphic: true

  validates_presence_of :marks, :penalty
end
