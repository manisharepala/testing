class QuestionImage
  include Mongoid::Document
  # include Mongoid::Paperclip

  embedded_in :question, :inverse_of => :question_images
  # field :image, type: BSON::Binary #move to s3 ?? or paperclip
  #
  # # belongs_to :tags_db
  # validates_presence_of :question_id, :image

  # has_mongoid_attached_file :attachment,
  #                           :url => "/ckeditor_assets/attachments/:id/:filename",
  #                           :path => ":rails_root/public/ckeditor_assets/attachments/:id/:filename"
  #
  # # validates_attachment_size :attachment, :less_than => 100.megabytes
  # validates_attachment_presence :attachment

end
