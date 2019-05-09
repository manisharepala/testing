class Ckeditor::Picture < Ckeditor::Asset
  has_mongoid_attached_file :data,
                            url: '/question_images/:id/:basename.:extension',
                            path: ':rails_root/public/question_images/:id/:basename.:extension'

  validates_attachment_size :data, less_than: 5.megabytes
  validates_attachment_presence :data
  validates_attachment_content_type :data, content_type: /\Aimage/

  def url_content
    url(:content)
  end
end
