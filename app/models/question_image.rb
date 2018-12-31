class QuestionImage
  include Mongoid::Document
  embedded_in :question
  field :image, type: BSON::Binary #move to s3 ?? or paperclip

  # belongs_to :tags_db
  validates_presence_of :question_id, :image
end
