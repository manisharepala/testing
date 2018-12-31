class QuizAttemptData
  include Mongoid::Document
  include Mongoid::Timestamps
  field :data, type: BSON::Binary
end
