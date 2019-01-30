class Image
  include Mongoid::Document
  field :key, type: String
  field :guid, type: String
  field :name, type: String
  field :file_path, type: String
  field :uploaded, type: Boolean, default: false

  before_create :create_guid
  # include Mongoid::Paperclip

  # embedded_in :question, :inverse_of => :images

  def create_guid
    self.guid = SecureRandom.uuid
  end

  def s3_server
    @s3_server ||= S3Server.new(guid: guid, type: 'Image')
  end

  def upload_image
    success = s3_server.upload_file(key_name: key, file_path: file_path)
    if success
      self.update_attributes(uploaded:success)
      File.delete(file_path) if File.exist?(file_path)
    end
  end

  def get_download_url
    s3_server.get_download_url(key)
  end

  def id
    self._id
  end

end