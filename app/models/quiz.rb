class Quiz
  include Mongoid::Document
  include Mongoid::Timestamps

  field :name, type: String
  field :description, type: String
  field :instructions, type: BSON::Binary
  field :total_marks, type: Float

  field :total_time, type: Integer # in minutes
  field :created_by, type: Integer
  field :tag_ids, type: Array
  field :question_ids, type: Array
  field :guid, type: String
  field :type, type: String
  field :key, type: String
  field :file_path, type: String
  field :final, type: Boolean, default: false
  field :uploaded, type: Boolean, default: false
  field :focus_area, type: BSON::Binary

  embeds_many :quiz_targeted_groups
  embeds_many :quiz_sections
  embeds_many :quiz_question_instances, as: :question_instances

  before_create :create_guid

  after_save :upload_zip

  # has_and_belongs_to_many :tags, index: true, autosave: true, inverse_of: nil # one side relation
  # has_and_belongs_to_many :questions, index: true, autosave: true, inverse_of: nil # one side relation
  # has_many :questions
  # accepts_nested_attributes_for :questions, :quiz_sections, :quiz_targeted_groups

  # has_and_belongs_to_many :tags, index: true, autosave: true, inverse_of: nil # one side


  # field :created_by, type: Integer
  # field :institution_id, type: Integer
  # field :center_id, type: Integer

  def create_guid
    self.guid = SecureRandom.uuid
  end

  def create_zip
    quiz = self

    quiz_zips_dir = Rails.root.to_s + "/public/quiz_zips/"
    zip_name = quiz_zips_dir + "#{quiz.guid}.zip"
    quiz_zip_path = quiz_zips_dir + quiz.guid + "/"

    FileUtils.mkdir_p (quiz_zips_dir) if !Dir.exists?(quiz_zips_dir)
    FileUtils.mkdir_p (quiz_zip_path) if !Dir.exists?(quiz_zip_path)

    question_images_path = Rails.root.to_s + "/public/question_images/"

    # FileUtils.rm_rf Dir.glob("#{dir_path}/*") if dir_path.present?
    quiz.question_ids.each do |id|
      FileUtils.mkdir_p (quiz_zip_path+id)
      FileUtils.cp_r(Dir["#{question_images_path+id}/*"],quiz_zip_path+id)
    end

    File.open(quiz_zip_path+"quiz_data.json","w") do |f|
      f.write((quiz.as_json).to_json)
    end

    Archive::Zip.archive(zip_name, quiz_zip_path)
  end

  def content_server
    @content_server ||= ContentServer.new(guid: guid, type: 'Quiz')
  end

  def upload_zip
    if final
      create_zip
      tags = {}
      tag_ids.each do |guid|
        data = TagsServer.get_tag_data(guid)
        d = {}
        d[data['name']] = data['guid']
        tags << d
      end
      # tags = {"grade"=>"177acf20-32ce-421b-8f32-c3b920c58e54", "subject"=>"fef249d0-4deb-454b-ba3a-70f6317f95d2", "chapter"=>"d84b02e8-6993-4e3a-9746-19de19a4b628", "concept"=>"99756e2f-b32b-417d-9fb4-190003131ce", "course"=>"99756e2f-b32b-417d-9fb4-190003131ce"}
      success = content_server.upload_file(name,file_path, tags)
      if success
        self.update_attributes(uploaded:success)
        # File.delete(file_path) if File.exist?(file_path)
      end
    end
  end

  def self.create_quiz(attrs)
    # byebug
    q = Quiz.send(:new, attrs)
    q.save!
  end

  def as_json(with_key: false)
    data = {name:name, description:description, instructions:instructions, total_marks:total_marks, total_time:total_time, type:type} #,quiz_detail:quiz_detail.as_json

    if quiz_sections.count > 0
      quiz_sections_data = []
      quiz_sections.each do |qs|
        qqi_data = {name:qs.name, instructions:qs.instructions}
        questions_data = []
        qs.quiz_question_instances.each do |qqi|
          if with_key
            questions_data << qqi.question.as_json(with_key:with_key)
          else
            questions_data << qqi.question.as_json
          end
        end
        qqi_data = qqi_data.merge(questions:questions_data)
        quiz_sections_data << qqi_data
      end
      data = data.merge(quiz_sections:quiz_sections_data)
    else
      questions_data = []
      question_ids.each do |id|
        q = Question.find(id)
        if with_key
          questions_data << q.as_json(with_key:with_key)
        else
          questions_data << q.as_json
        end
      end
      data = data.merge(questions:questions_data)
    end

    return data
  end

end
