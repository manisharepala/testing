class S3Server
  include HTTParty
  base_uri '13.233.76.145'
  UPLOAD_URL = '/s3/add_file'
  attr_reader :guid, :type, :user_id

  def initialize guid: , type: , user_id: 13
    @guid = guid
    @type = type
    @user_id = user_id
  end

  def upload_file(key_name:  ,file_path: )
    res = self.class.put(
      UPLOAD_URL,
      headers: headers,
      body: {
        asset: {
          guid: guid,
          type: type,
          key_name: key_name
        },
        file: File.open(file_path)
      }
    )
    puts res
    res.success? ? true : false
  end

  def get_file key_name: , file_path:
    download_url = get_download_url key_name
    raise Exception.new('Invalid Key') unless download_url
    File.open(file_path, "w") do |file|
      self.class.get(download_url, stream_body: true) do |fragment|
        file.write(fragment)
      end
    end
  end

  def get_file_details key_name
    res = self.class.get(details_url(key_name))
    res.success? ? JSON.parse(res.body) : false
  end

  def get_download_url key_name
    res = self.class.get(download_url(key_name), headers: headers)
    res.success? ? JSON.parse(res.body)['url'] : false
  end

  def delete_file key_name
    res = self.class.delete(delete_file_url(key_name), headers: headers)
    res.success? ? true : false
  end

  def delete_asset
    res = self.class.delete(delete_asset_url, headers: headers)
    res.success? ? true : false
  end

  def self.download_quiz_zip(guid)
    tempfile = Tempfile.new("quiz.zip")
    res = get(S3Server.quiz_zip_download_url(guid))
    File.open(tempfile.path,"w+b", 0644 ) do |file|
      # get(S3Server.quiz_zip_download_url(guid), stream_body: true) do |fragment|
      #   file.write(fragment)
      # end
      file.write res.body
    end
    return tempfile
  end

  private

  def self.quiz_zip_download_url(guid)
    "/content_assets/#{guid}/original_attachment"
  end

  def headers
    {token: user_id.to_s}
  end

  def delete_asset_url
    "/s3/asset/#{guid}/#{type}"
  end

  def delete_file_url key_name
    "/s3/file/#{guid}/#{type}?key_name=#{key_name}"
  end

  def download_url key_name
    "/s3/download_url/#{guid}/#{type}?key_name=#{key_name}"
  end

  def details_url key_name
    "/s3/file_details/#{guid}/#{type}?key_name=#{key_name}"
  end
end
