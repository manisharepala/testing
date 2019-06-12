class ContentServer
  include HTTParty
  base_uri '13.234.165.191'
  # base_uri 'localhost:6000'
  CREATION_URL = '/content_assets.json'
  attr_reader :guid, :type, :user_id

  def initialize guid: , type: , user_id: 13
    @guid = guid
    @type = type
    @user_id = user_id
  end

  def upload_file(name,file_path,tags)
    res = self.class.post(
        CREATION_URL,
        headers: headers,
        body: {
            content_asset: {
                name: name,
                guid: guid,
                asset_type: type,
                # icon: File.open(file_path),
                attachment: File.open(file_path)
            },
            grade: tags['grade'],
            subject: tags['subject'],
            chapter: tags['chapter'],
            concept: tags['concept'],
            course: tags['course']
        }
    )
    puts res
    res.success? ? true : false
  end

  def update_file(name,file_path,tags)
    res = self.class.put(
        "/content_assets/#{guid}.json",
        headers: headers,
        body: {
            content_asset: {
                name: name,
                # icon: File.open(file_path),
                attachment: File.open(file_path)
            },
            grade: tags['grade'],
            subject: tags['subject'],
            chapter: tags['chapter'],
            concept: tags['concept'],
            course: tags['course']
        }
    )
    puts res
    res.success? ? true : false
  end

  def self.get_quiz_zip

  end

  def self.get_concept_chapters(concept_guids,token)
    res = get("/api/v1/content/get_concept_chapters",headers:{token:token}, body: {concept_guids:concept_guids})
    res.success? ? JSON.parse(res.body) : false
  end

  def headers
    {token: "eyJhbGciOiJIUzI1NiJ9.eyJ1c2VybmFtZSI6InN0cmluZyIsImVtYWlsIjoidXNlckBleGFtcGxlLmNvbSIsInJvbGxfbm8iOiJzdHJpbmciLCJ1c2VyX2lkIjoxLCJzdWIiOiIxIiwic2NwIjoidXNlciIsImF1ZCI6bnVsbCwiaWF0IjoxNTQ4MDY0Njg1LCJleHAiOjE1NDgxNTEwODUsImp0aSI6IjlmYWEzYTM1LTBmMjYtNDM4YS05ZWUyLTBlZDA0NTI2ZjVlNCJ9.x9C769SkwTGPDLEdrkXx2KlY4UoA7WA47RQXTaKscnk"}
  end

  # @content_server ||= ContentServer.new(guid: "9788b5d5-a2a9-4439-8abf-efd09838cdc3", type: 'assessment')
  # @content_server.upload_file('quiz1', "/home/inayath/edutor/assessment_app/public/quiz_zips/9788b5d5-a2a9-4439-8abf-efd09838cdc3.zip", {"grade"=>"177acf20-32ce-421b-8f32-c3b920c58e54", "subject"=>"fef249d0-4deb-454b-ba3a-70f6317f95d2", "chapter"=>"d84b02e8-6993-4e3a-9746-19de19a4b628", "concept"=>"99756e2f-b32b-417d-9fb4-190003131ce", "course"=>"99756e2f-b32b-417d-9fb4-190003131ce"})

end
