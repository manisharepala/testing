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
    res = self.class.get(details_url(key_name),headers:headers)
    res.success? ? JSON.parse(res.body) : false
  end

  def get_download_url key_name
    res = self.class.get(download_url(key_name), headers: headers)
    res.success? ? (JSON.parse(res.body))['url'] : false
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
    res = get(S3Server.quiz_zip_download_url(guid),headers:headers)
    File.open(tempfile.path,"w+b", 0644 ) do |file|
      file.write res.body
    end
    return tempfile
  end

  private

  def self.quiz_zip_download_url(guid)
    "/content_assets/#{guid}/original_attachment"
  end

  def self.headers
    {token: "eyJhbGciOiJIUzI1NiJ9.eyJ1c2VybmFtZSI6InN0cmluZyIsImVtYWlsIjoidXNlckBleGFtcGxlLmNvbSIsInJvbGxfbm8iOiJzdHJpbmciLCJ1c2VyX2lkIjoxLCJzdWIiOiIxIiwic2NwIjoidXNlciIsImF1ZCI6bnVsbCwiaWF0IjoxNTQ4MDY0Njg1LCJleHAiOjE1NDgxNTEwODUsImp0aSI6IjlmYWEzYTM1LTBmMjYtNDM4YS05ZWUyLTBlZDA0NTI2ZjVlNCJ9.x9C769SkwTGPDLEdrkXx2KlY4UoA7WA47RQXTaKscnk"}
  end

  def headers
    {token: "eyJhbGciOiJIUzI1NiJ9.eyJ1c2VybmFtZSI6InN0cmluZyIsImVtYWlsIjoidXNlckBleGFtcGxlLmNvbSIsInJvbGxfbm8iOiJzdHJpbmciLCJ1c2VyX2lkIjoxLCJzdWIiOiIxIiwic2NwIjoidXNlciIsImF1ZCI6bnVsbCwiaWF0IjoxNTQ4MDY0Njg1LCJleHAiOjE1NDgxNTEwODUsImp0aSI6IjlmYWEzYTM1LTBmMjYtNDM4YS05ZWUyLTBlZDA0NTI2ZjVlNCJ9.x9C769SkwTGPDLEdrkXx2KlY4UoA7WA47RQXTaKscnk"}
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

  # publisher
  #eyJhbGciOiJIUzI1NiJ9.eyJ1c2VybmFtZSI6ImtyaXNobmExMiIsImVtYWlsIjpudWxsLCJyb2xsX25vIjpudWxsLCJ1c2VyX2lkIjoxMiwic3ViIjoiMTIiLCJzY3AiOiJ1c2VyIiwiYXVkIjpudWxsLCJpYXQiOjE1NDgwNjY3NDUsImV4cCI6MTU0ODE1MzE0NSwianRpIjoiZGFiNGI0MjQtMzQ0Ny00N2I1LWEwN2MtZjVhY2UxNzkyNjJkIn0.91Pl73VJqFR0lUPG30NqstOE0E1DVurCZK-JssNURtM
  #admin
  #eyJhbGciOiJIUzI1NiJ9.eyJ1c2VybmFtZSI6InN0cmluZyIsImVtYWlsIjoidXNlckBleGFtcGxlLmNvbSIsInJvbGxfbm8iOiJzdHJpbmciLCJ1c2VyX2lkIjoxLCJzdWIiOiIxIiwic2NwIjoidXNlciIsImF1ZCI6bnVsbCwiaWF0IjoxNTQ4MDY0Njg1LCJleHAiOjE1NDgxNTEwODUsImp0aSI6IjlmYWEzYTM1LTBmMjYtNDM4YS05ZWUyLTBlZDA0NTI2ZjVlNCJ9.x9C769SkwTGPDLEdrkXx2KlY4UoA7WA47RQXTaKscnk
end
