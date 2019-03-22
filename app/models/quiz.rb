class Quiz
  include Mongoid::Document
  include Mongoid::Timestamps

  # field :name, type: String
  # field :description, type: String
  # field :instructions, type: BSON::Binary
  embeds_many :quiz_language_specific_datas, cascade_callbacks: true
  accepts_nested_attributes_for :quiz_language_specific_datas
  field :total_marks, type: Float, default:100

  field :total_time, type: Integer, default:180 # in minutes
  field :created_by, type: Integer
  field :tag_ids, type: Array, default: []
  field :question_ids, type: Array, default: []
  field :guid, type: String
  field :type, type: String
  field :player, type: String
  field :key, type: String
  field :file_path, type: String
  field :final, type: Boolean, default: false
  field :uploaded, type: Boolean, default: false
  field :focus_area, type: BSON::Binary
  field :quiz_json, type: BSON::Binary

  #embeds_many :quiz_targeted_groups
  has_many :quiz_sections
  field :quiz_section_ids, type: Array, default: []
  #embeds_many :quiz_question_instances, as: :question_instances

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

  def id
    self._id.to_s
  end

  def create_zip
    quiz = self

    quiz_zips_dir = Rails.root.to_s + "/public/quiz_zips/"
    zip_name = quiz_zips_dir + "#{quiz.guid}.zip"
    quiz_zip_path = quiz_zips_dir + quiz.guid + "/"

    FileUtils.mkdir_p (quiz_zips_dir) if !Dir.exists?(quiz_zips_dir)
    FileUtils.mkdir_p (quiz_zip_path) if !Dir.exists?(quiz_zip_path)

    question_images_path = Rails.root.to_s + "/public/question_images/"

    quiz.question_ids.each do |id|
      FileUtils.mkdir_p (quiz_zip_path+id)
      FileUtils.cp_r(Dir["#{question_images_path+id}/*"],quiz_zip_path+id)
    end

    File.open(quiz_zip_path+"assessment.json","w") do |f|
      if (1==1)
        f.write((quiz.as_json(with_key:true)).to_json)
      else
        f.write((quiz.as_json(with_key:true, with_language_support:true)).to_json)
      end
    end

    Archive::Zip.archive(zip_name, quiz_zip_path)
    FileUtils.rm_rf Dir.glob("#{zip_name.gsub('.zip','')}") if (zip_name.gsub('.zip','')).present?
  end

  def s3_server
    @s3_server ||= S3Server.new(guid: guid, type: 'assessment')
  end

  def content_server
    @content_server ||= ContentServer.new(guid: guid, type: 'assessment')
  end

  def self.get_json_from_s3(guid)
    require 'zip'
    tempfile = S3Server.download_quiz_zip(guid)
    content = {}
    Zip::File.open(tempfile) do |zip_file|
      zip_file.each do |entry|
        if entry.name == "assessment.json"
          content = entry.get_input_stream.read
        end
      end
    end
    return content
  end

  def upload_zip
    if final
      create_zip
      tags = {}
      #  tag_ids.each do |guid|
      #    data = TagsServer.get_tag_data(guid)
      #    d = {}
      #    d[data['name']] = data['guid']
      #    tags << d
      #  end
      # tags = {"grade"=>"177acf20-32ce-421b-8f32-c3b920c58e54", "subject"=>"fef249d0-4deb-454b-ba3a-70f6317f95d2", "chapter"=>"d84b02e8-6993-4e3a-9746-19de19a4b628", "concept"=>"99756e2f-b32b-417d-9fb4-190003131ce", "course"=>"99756e2f-b32b-417d-9fb4-190003131ce"}
      success = content_server.upload_file(name,file_path, tags)
      if success
        self.update_attributes(uploaded:success)
        File.delete(file_path) if File.exist?(file_path)
      end
    end
  end

  def self.create_quiz(attrs)
    # byebug
    q = Quiz.send(:new, attrs)
    q.save!
  end

  def as_json(with_key: false,with_language_support: false)
    quiz_name_data = {}
    quiz_description_data = {}
    quiz_instructions_data = {}

    quiz_language_specific_datas.each do |d|
      quiz_name_data[d.language] = d.name
      quiz_description_data[d.language] = d.description
      quiz_instructions_data[d.language] = d.instructions
    end

    if with_language_support
      data = {name:quiz_name_data, description:quiz_description_data, instructions:quiz_instructions_data, total_marks:total_marks, total_time:total_time, player:player, languages_supported:['english','hindi']}
    else
      data = {name:quiz_name_data['english'], description:quiz_description_data['english'], instructions:quiz_instructions_data['english'], total_marks:total_marks, total_time:total_time, player:player, languages_supported:['english']}
    end

    tags_data = []
    tag_ids.each do |guid|
      d = TagsServer.get_tag_data(guid)
      tags_data << {d['name']=>d['value']} if d.present?
    end
    # tags_data = [{"course"=>"CBSE"}, {"grade"=>"4"}, {"subject"=>"Social"}, {"chapter"=>"Our Natural Resources – Soil and Water"}, {"concept"=>"Our Natural Resources – Soil and Water"}]
    data.merge(tags:tags_data)

    if quiz_section_ids.count > 0
      q_ids = quiz_section_ids.map{|qs_id| QuizSection.find(qs_id).question_ids}.flatten
      quiz_sections_data = []
      quiz_section_ids.each do |qs_id|
        qs = QuizSection.find(qs_id)
        quiz_sections_data << qs.as_json(with_language_support:with_language_support)
      end
    else
      q_ids = question_ids
      quiz_sections_data = []
    end

    questions_data = []
    q_ids.each do |id|
      q = Question.find(id)
      questions_data << q.as_json(with_key:with_key,with_language_support:with_language_support)
    end
    data = data.merge(questions:questions_data)
    data = data.merge(quiz_sections:quiz_sections_data)

    return JSON.parse(data.to_json)
  end

  def self.migrate_quizzes(guid)
    require 'zip'
    guid = "f1a77f71-3044-40bb-add6-052d51cdea44" #objective
    guid = "6176cb03-6305-42bb-b8ca-2fdb77e9a044" #subjective
    tempfile = S3Server.download_quiz_zip(guid)
    zip_path = File.join(Rails.root.to_s,"public/quiz_zips/#{guid}") #"/home/inayath/edutor/assessment_app/public/quiz_zips/472508b1-6f7d-4f80-a1f0-b4ca4202be7b"
    FileUtils.mkdir_p (zip_path)
    Archive::Zip.extract(tempfile, zip_path)

    data = JSON.parse(File.read(zip_path+"/assessment.json"))

    images_dir = zip_path + "/#{data['name']}_files"
    user_id = 1
    publisher_question_bank_id = PublisherQuestionBank.first._id
    publisher_question_bank = PublisherQuestionBank.find(publisher_question_bank_id)
    s3_path = '/question_images/'

    data.keys #[:name, :description, :instructions, :total_marks, :total_time, :player, :time_open, :time_close, :questions]

    tags_not_present = []
    question_wise_tags_not_present = []
    tags_not_present_data = Quiz.verify_tags(data)
    tags_not_present += tags_not_present_data[0]
    question_wise_tags_not_present += tags_not_present_data[1]

    question_ids = []

    if (tags_not_present.count == 0) && (question_wise_tags_not_present.count == 0)
      data[:questions].each do |ques_data|
        question = Question.create_question(Quiz.get_simple_question_hash(ques_data,user_id,publisher_question_bank_id))
        Quiz.update_image_path(question._id,s3_path)
        Quiz.copy_question_images(question._id,images_dir)
        question_ids << question._id
      end
      publisher_question_bank.attributes = {question_ids:(publisher_question_bank.question_ids + question_ids)}
      publisher_question_bank.save!

      quiz = Quiz.create!(name:data[:name], description:data[:description], instructions:data[:instructions], total_marks:data[:total_marks], total_time:data[:total_time],player:data[:player], type:data[:player], time_open:data[:time_open], time_close:data[:time_close])
      quiz.question_ids = question_ids
      quiz.key = "/quiz_zips/#{quiz.guid}.zip"
      quiz.file_path = Rails.root.to_s + "/public/quiz_zips/#{quiz.guid}.zip"
      quiz.quiz_json = data
      quiz.final = true
      quiz.save!
    else
      logger.info "Tags not present -------------------------------- #{tags_not_present}"
      raise Exception.new("Following tags are not present #{tags_not_present} and Following questions do not have the compulsory 5 tags -> #{question_wise_tags_not_present} ")
    end
  end

  def Quiz.update_image_path(ques_id,s3_path)
    question = Question.find(ques_id)
    question.update_attributes(question_text:Quiz.update_img_src(question.question_text,s3_path,ques_id), general_feedback:Quiz.update_img_src(question.general_feedback,s3_path,ques_id))
    if question.qtype == 'MmcqQuestion' || question.qtype == 'SmcqQuestion'
      question.question_answers.each do |qa|
        qa.update_attributes(answer:Quiz.update_img_src(qa.answer,s3_path,ques_id))
      end
    end
  end

  def Quiz.update_img_src(text,s3_path,ques_id)
    if text.present?
      text = JSON.parse(text)
      replacement_paths = []
      Nokogiri::HTML(text).css('img').map{ |i| i['src'] }.each do |img|
        replacement_paths << (img.reverse.split('/', 2).map(&:reverse).reverse)[0]
      end
      replacement_paths.uniq.each do |rp|
        text = text.gsub(rp, s3_path+ques_id)
      end
      ['.png', '.wmz'].each do |f|
        text = text.gsub(f, '.jpg')
      end
    else
      text = ''
    end
    return text
  end

  def Quiz.copy_question_images(ques_id, images_dir)
    ques_images = []
    question = Question.find(ques_id)
    Nokogiri::HTML(question.question_text).css('img').map{ |i| i['src'] }.each do |img|
      ques_images << img.split("/").last
    end

    Nokogiri::HTML(question.general_feedback).css('img').map{ |i| i['src'] }.each do |img|
      ques_images << img.split("/").last
    end

    if question.qtype == 'MmcqQuestion' || question.qtype == 'SmcqQuestion'
      question.question_answers.each do |qa|
        Nokogiri::HTML(qa.answer).css('img').map{ |i| i['src'] }.each do |img|
          ques_images << img.split("/").last
        end
      end
    end

    if question.qtype == 'Passage'
      question.questions.each do |q|
        copy_question_images(q._id,images_dir)
      end
    end

    ques_images = ques_images.uniq
    image_names = ques_images.map{|n| n.downcase.split('.')[0]}
    image_ids = []

    dir_path = Rails.root.to_s + "/public/question_images/#{ques_id}/"
    FileUtils.mkdir_p(dir_path)
    Dir["#{images_dir}/*"].each do |img|
      index = image_names.index(File.basename(img).split('.')[0].downcase)

      if index.present?
        # copying to public folder
        img_name = (ques_images[index]).split('.')[0] + ".jpg"
        image = Magick::Image.read(img).first
        image.write(dir_path+img_name)

        # creating Image reference for S3
        image_ids << (Image.create(name: img_name, key: "/question_images/#{ques_id}/#{img_name}", file_path:(dir_path+img_name))).guid
      end

    end
    question.image_ids = image_ids
    question.save!
    question.upload_images
  end

  def Quiz.verify_tags(data)
    all_tags = []
    tag_not_present = []
    must_present_tag_names_for_each_question = ["course", "grade", "subject", "chapter", "concept"]
    question_wise_tags_not_present = []

    tags_hash = {"academic_class"=>"grade", "concept_names"=>"concept", "course"=>"course", "chapter"=>"chapter", "subject"=>"subject"}

    data['questions'].each_with_index do |ques,i|
      tag_names = []
      ques['tags'].each do |tag|
        name = tags_hash[tag.keys[0]]
        value = tag.values[0]
        d = {}
        d['name'] = name
        d['value'] = value
        tag_names << name
        all_tags << d
        if !TagsServer.get_tag_guid(name, value).present?
          tag_not_present << d
        end
      end
      absent_tags = must_present_tag_names_for_each_question - tag_names
      if absent_tags.count > 0
        question_tag_not_present = {}
        question_tag_not_present['id'] = ques['id']
        question_tag_not_present['type'] = ques['question_type']
        question_tag_not_present['tags_not_present'] = absent_tags
        question_wise_tags_not_present << question_tag_not_present
      end
    end
    logger.info "All tags - #{all_tags.count} - #{all_tags}"
    return [tag_not_present,question_wise_tags_not_present]
  end

  def Quiz.get_simple_question_hash(ques_data,user_id,publisher_question_bank_id)
    #[:id, :question_text, :marks, :penalty, :question_type, :tags, :explanation, :hint, :options, :answers, :blanks]
    data = {}
    data['publisher_question_bank_ids'] = [publisher_question_bank_id]
    data['created_by'] = user_id
    data['question_text'] = ques_data['question_text']
    data['default_mark'] = ques_data['marks']
    data['penalty'] = ques_data['penalty']
    data['qtype'] = ques_data['question_type']
    data['qtype'] = 'SubjectiveQuestion' if ques_data['question_type'] == nil
    data['generalfeedback'] = data['explanation']
    data['hint'] = ques_data['hint']

    data['tag_ids'] = []
    ques_data['tags'].each do |tag|
      data['tag_ids'] << "abcde" #TagsServer.get_tag_guid(tag.keys[0], tag.values[0])
    end

    if ['SmcqQuestion', 'MmcqQuestion', 'TrueFalseQuestion'].include? ques_data['question_type']
      data['question_answers_attributes'] = []
      ques_data['options'].each do |option|
        option_data = {}
        option_data['answer'] = option['option_text']
        option_data['feedback'] = ""

        if (ques_data['answers'].flatten).include? option['id']
          option_data['fraction'] = true
        else
          option_data['fraction'] = false
        end

        data['question_answers_attributes'] << option_data
      end
    elsif ['FibQuestion'].include? data['question_type']
      data['question_fill_blanks_attributes'] = []
      # ques.xpath("question/options_fib").each do |option|
      #   data['question_fill_blanks_attributes'] << get_question_fill_blank_hash(option)
      # end
    end

    return data
  end

  def self.sss
    ["mp4", "zip", "pdf", "mp3", "json"]
    ["mp4", "pdf", "assessment", "html5", "toc"]

    require 'zip'
    result_data = []

    name = ''
    type = ''
    tags = {"grade"=>"177acf20-32ce-421b-8f32-c3b920c58e54"}
    guid = "0e6dcd16-38f9-4346-8685-a326ae641d24"

    data = [{"guid"=>"40be7d42-3b35-435a-b5e7-5b355721f97d", "asset_type"=>"ContentAsset", "file_extension"=>"mp4", "key"=>"content_assets/40be7d42-3b35-435a-b5e7-5b355721f97d/original/Pg_21.mp4"}, {"guid"=>"5bed4cc5-e5c9-4e79-a8d2-b27960a53070", "asset_type"=>"ContentAsset", "file_extension"=>"mp4", "key"=>"content_assets/5bed4cc5-e5c9-4e79-a8d2-b27960a53070/original/Ch6_pg146_Pg_234.mp4"}, {"guid"=>"b6cded1d-4aa4-4104-8b38-21ba18352ca3", "asset_type"=>"ContentAsset", "file_extension"=>"mp4", "key"=>"content_assets/b6cded1d-4aa4-4104-8b38-21ba18352ca3/original/Animals_Have_Feeling.mp4"}, {"guid"=>"3b7799a5-5937-42e0-b888-e9a58b9e4864", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/3b7799a5-5937-42e0-b888-e9a58b9e4864/encrypt/app_3b7799a5-5937-42e0-b888-e9a58b9e4864.zip"}, {"guid"=>"80da0961-72bd-4197-ae9c-168d20033993", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/80da0961-72bd-4197-ae9c-168d20033993/encrypt/app_80da0961-72bd-4197-ae9c-168d20033993.zip"}, {"guid"=>"618f563b-68f1-4026-b39d-cb511d8d6685", "asset_type"=>"ContentAsset", "file_extension"=>"mp4", "key"=>"content_assets/618f563b-68f1-4026-b39d-cb511d8d6685/original/ch1_pg8_Leaf_and_its_Structure_-expl.mp4"}, {"guid"=>"d350f8d6-a31e-4e27-88dc-97459af2b042", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/d350f8d6-a31e-4e27-88dc-97459af2b042/encrypt/app_d350f8d6-a31e-4e27-88dc-97459af2b042.zip"}, {"guid"=>"d3e913fe-eaab-4a86-832f-d8a048b41d81", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/d3e913fe-eaab-4a86-832f-d8a048b41d81/encrypt/app_d3e913fe-eaab-4a86-832f-d8a048b41d81.zip"}, {"guid"=>"8115ad57-daa1-4c3f-9872-2b63c90d0b97", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/8115ad57-daa1-4c3f-9872-2b63c90d0b97/encrypt/app_8115ad57-daa1-4c3f-9872-2b63c90d0b97.zip"}, {"guid"=>"f15a6726-9211-4fe3-b17d-08fa1699470a", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/f15a6726-9211-4fe3-b17d-08fa1699470a/encrypt/app_f15a6726-9211-4fe3-b17d-08fa1699470a.zip"}, {"guid"=>"6d117b8c-8a11-4563-bff6-89129c60adeb", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/6d117b8c-8a11-4563-bff6-89129c60adeb/encrypt/app_6d117b8c-8a11-4563-bff6-89129c60adeb.zip"}, {"guid"=>"15355e00-163e-4825-b2bd-0d35bfa14d7d", "asset_type"=>"ContentAsset", "file_extension"=>"mp4", "key"=>"content_assets/15355e00-163e-4825-b2bd-0d35bfa14d7d/original/ch2_page29_Division.mp4"}, {"guid"=>"648fae95-b0ad-4da7-b166-467d61274ca1", "asset_type"=>"ContentAsset", "file_extension"=>"pdf", "key"=>"content_assets/648fae95-b0ad-4da7-b166-467d61274ca1/original/1.pdf"}, {"guid"=>"04d66d7b-f158-497b-b084-e32ab23dd640", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/04d66d7b-f158-497b-b084-e32ab23dd640/encrypt/app_04d66d7b-f158-497b-b084-e32ab23dd640.zip"}, {"guid"=>"5a367432-0904-4f2a-a4c0-fb4ce773a4df", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/5a367432-0904-4f2a-a4c0-fb4ce773a4df/encrypt/app_5a367432-0904-4f2a-a4c0-fb4ce773a4df.zip"}, {"guid"=>"e8ed8081-a610-4dcd-9f56-eb24bcb38933", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/e8ed8081-a610-4dcd-9f56-eb24bcb38933/encrypt/app_e8ed8081-a610-4dcd-9f56-eb24bcb38933.zip"}, {"guid"=>"d84fe812-f9e4-455e-b335-59c00af92792", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/d84fe812-f9e4-455e-b335-59c00af92792/encrypt/app_d84fe812-f9e4-455e-b335-59c00af92792.zip"}, {"guid"=>"e1301818-3448-4a8d-967d-6ba384c00163", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/e1301818-3448-4a8d-967d-6ba384c00163/encrypt/app_e1301818-3448-4a8d-967d-6ba384c00163.zip"}, {"guid"=>"f30a45b6-c551-4c27-9be5-a62a46216c80", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/f30a45b6-c551-4c27-9be5-a62a46216c80/encrypt/app_f30a45b6-c551-4c27-9be5-a62a46216c80.zip"}, {"guid"=>"8702d0c9-97b6-4538-a233-50606cf32e11", "asset_type"=>"ContentAsset", "file_extension"=>"mp3", "key"=>"content_assets/8702d0c9-97b6-4538-a233-50606cf32e11/original/chap7_pg104.mp3"}, {"guid"=>"3e408e82-a23a-4136-9ded-9afc1f390785", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/3e408e82-a23a-4136-9ded-9afc1f390785/encrypt/app_3e408e82-a23a-4136-9ded-9afc1f390785.zip"}, {"guid"=>"04777867-1d62-4c03-8324-414f3a2ddc63", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/04777867-1d62-4c03-8324-414f3a2ddc63/encrypt/app_04777867-1d62-4c03-8324-414f3a2ddc63.zip"}, {"guid"=>"5175d3dc-0f3a-4a58-9ab5-7c2ccec6aa79", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/5175d3dc-0f3a-4a58-9ab5-7c2ccec6aa79/encrypt/app_5175d3dc-0f3a-4a58-9ab5-7c2ccec6aa79.zip"}, {"guid"=>"bf78f85c-3045-4611-8917-3954ba3504e9", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/bf78f85c-3045-4611-8917-3954ba3504e9/encrypt/app_bf78f85c-3045-4611-8917-3954ba3504e9.zip"}, {"guid"=>"7b44b978-8515-4cfd-936a-adc4b2f92b86", "asset_type"=>"ContentAsset", "file_extension"=>"mp3", "key"=>"content_assets/7b44b978-8515-4cfd-936a-adc4b2f92b86/original/chap7_pg100.mp3"}, {"guid"=>"c60e4d09-959b-4388-8ace-7ce2794c8894", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/c60e4d09-959b-4388-8ace-7ce2794c8894/encrypt/app_c60e4d09-959b-4388-8ace-7ce2794c8894.zip"}, {"guid"=>"6dd103d5-fcf8-4c25-ace9-be6af4f2f27d", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/6dd103d5-fcf8-4c25-ace9-be6af4f2f27d/encrypt/app_6dd103d5-fcf8-4c25-ace9-be6af4f2f27d.zip"}, {"guid"=>"beea6416-d3c5-4bfd-afd5-25a143437a8a", "asset_type"=>"ContentAsset", "file_extension"=>"mp4", "key"=>"content_assets/beea6416-d3c5-4bfd-afd5-25a143437a8a/original/Main_and_Auxiliary_Verbs.mp4"}, {"guid"=>"047f3b5c-bf1c-4474-b38a-17c88a7ada6f", "asset_type"=>"ContentAsset", "file_extension"=>"mp3", "key"=>"content_assets/047f3b5c-bf1c-4474-b38a-17c88a7ada6f/original/chap1_pg9_Summary.mp3"}, {"guid"=>"50caca55-680a-45ea-a138-f19ebcbe9c04", "asset_type"=>"ContentAsset", "file_extension"=>"mp3", "key"=>"content_assets/50caca55-680a-45ea-a138-f19ebcbe9c04/original/chap1_pg8.mp3"}, {"guid"=>"77aa4275-dd68-40d9-8c47-e3f8b2daba12", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/77aa4275-dd68-40d9-8c47-e3f8b2daba12/encrypt/app_77aa4275-dd68-40d9-8c47-e3f8b2daba12.zip"}, {"guid"=>"de193d25-3297-4cba-b247-21a94d2e267b", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/de193d25-3297-4cba-b247-21a94d2e267b/encrypt/app_de193d25-3297-4cba-b247-21a94d2e267b.zip"}, {"guid"=>"c6e9e8ce-ac68-4a8e-b812-04047e2e05e9", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/c6e9e8ce-ac68-4a8e-b812-04047e2e05e9/encrypt/app_c6e9e8ce-ac68-4a8e-b812-04047e2e05e9.zip"}, {"guid"=>"8f6bff8f-ad70-4775-8ee2-9135cd7adb3b", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/8f6bff8f-ad70-4775-8ee2-9135cd7adb3b/encrypt/app_8f6bff8f-ad70-4775-8ee2-9135cd7adb3b.zip"}, {"guid"=>"63517570-ec04-429e-b6de-715696d0ff94", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/63517570-ec04-429e-b6de-715696d0ff94/encrypt/app_63517570-ec04-429e-b6de-715696d0ff94.zip"}, {"guid"=>"0b502f85-6baa-48fc-9b24-2f02ed5a132e", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/0b502f85-6baa-48fc-9b24-2f02ed5a132e/encrypt/app_0b502f85-6baa-48fc-9b24-2f02ed5a132e.zip"}, {"guid"=>"60189ee5-a988-406b-93be-4a1476578a5d", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/60189ee5-a988-406b-93be-4a1476578a5d/encrypt/app_60189ee5-a988-406b-93be-4a1476578a5d.zip"}, {"guid"=>"b846e205-6c0c-43c9-b2d8-87585d4d08d9", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/b846e205-6c0c-43c9-b2d8-87585d4d08d9/encrypt/app_b846e205-6c0c-43c9-b2d8-87585d4d08d9.zip"}, {"guid"=>"47885860-a8e4-4c9f-b7b2-089bd72be298", "asset_type"=>"ContentAsset", "file_extension"=>"mp4", "key"=>"content_assets/47885860-a8e4-4c9f-b7b2-089bd72be298/original/Kinds_Of_Sentences.mp4"}, {"guid"=>"70db61c5-348f-4db5-b5e7-a96cc3365a6e", "asset_type"=>"ContentAsset", "file_extension"=>"json", "key"=>"content_assets/70db61c5-348f-4db5-b5e7-a96cc3365a6e/original/humanities.json"}, {"guid"=>"d79652f2-7e83-4ba2-9589-c13f403d46c6", "asset_type"=>"ContentAsset", "file_extension"=>"mp4", "key"=>"content_assets/d79652f2-7e83-4ba2-9589-c13f403d46c6/original/ch1_pg11_insectivorous_plants.mp4"}, {"guid"=>"0ffb65fa-9757-4e16-93aa-b275ed827a9e", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/0ffb65fa-9757-4e16-93aa-b275ed827a9e/encrypt/app_0ffb65fa-9757-4e16-93aa-b275ed827a9e.zip"}, {"guid"=>"e64efd1d-ab87-4772-9111-ca57d6d8b10e", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/e64efd1d-ab87-4772-9111-ca57d6d8b10e/encrypt/app_e64efd1d-ab87-4772-9111-ca57d6d8b10e.zip"}, {"guid"=>"10238c6b-a286-49b9-b2f8-efa3cd2a2882", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/10238c6b-a286-49b9-b2f8-efa3cd2a2882/encrypt/app_10238c6b-a286-49b9-b2f8-efa3cd2a2882.zip"}, {"guid"=>"900bc3d9-92d2-4853-a864-465741b0bbf8", "asset_type"=>"ContentAsset", "file_extension"=>"mp3", "key"=>"content_assets/900bc3d9-92d2-4853-a864-465741b0bbf8/original/ch1_pg10.mp3"}, {"guid"=>"7246d432-fa99-4770-8a8d-f1229258987c", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/7246d432-fa99-4770-8a8d-f1229258987c/encrypt/app_7246d432-fa99-4770-8a8d-f1229258987c.zip"}, {"guid"=>"ca8570cb-310d-44e7-b7ba-212a84153f25", "asset_type"=>"ContentAsset", "file_extension"=>"mp3", "key"=>"content_assets/ca8570cb-310d-44e7-b7ba-212a84153f25/original/chap7_pg93.mp3"}, {"guid"=>"51201c9b-146b-4a6d-8cf9-8d941786387a", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/51201c9b-146b-4a6d-8cf9-8d941786387a/encrypt/app_51201c9b-146b-4a6d-8cf9-8d941786387a.zip"}, {"guid"=>"bb1e5f7d-62dd-4e54-9f6d-fbf316b7e7dd", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/bb1e5f7d-62dd-4e54-9f6d-fbf316b7e7dd/encrypt/app_bb1e5f7d-62dd-4e54-9f6d-fbf316b7e7dd.zip"}, {"guid"=>"634b267a-59ff-440b-988a-53016ade9787", "asset_type"=>"ContentAsset", "file_extension"=>"mp3", "key"=>"content_assets/634b267a-59ff-440b-988a-53016ade9787/original/chap7_pg98.mp3"}, {"guid"=>"2b7aaf35-8171-480d-a57b-5676e6f0579a", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/2b7aaf35-8171-480d-a57b-5676e6f0579a/encrypt/app_2b7aaf35-8171-480d-a57b-5676e6f0579a.zip"}, {"guid"=>"8ab0c369-1135-4983-a92b-5cdf54242ee6", "asset_type"=>"ContentAsset", "file_extension"=>"mp3", "key"=>"content_assets/8ab0c369-1135-4983-a92b-5cdf54242ee6/original/chap7_pg99.mp3"}, {"guid"=>"9495c7d4-5fee-4dfd-bc78-934c33b792f5", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/9495c7d4-5fee-4dfd-bc78-934c33b792f5/encrypt/app_9495c7d4-5fee-4dfd-bc78-934c33b792f5.zip"}, {"guid"=>"ad20a85b-349f-416a-993d-4adc18ebcac5", "asset_type"=>"ContentAsset", "file_extension"=>"mp3", "key"=>"content_assets/ad20a85b-349f-416a-993d-4adc18ebcac5/original/ch1_pg5.mp3"}, {"guid"=>"339bb01d-dfe3-4a97-98f1-d2f2870b2d9a", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/339bb01d-dfe3-4a97-98f1-d2f2870b2d9a/encrypt/app_339bb01d-dfe3-4a97-98f1-d2f2870b2d9a.zip"}, {"guid"=>"d21b3605-038c-4dad-9543-8fd88b2e0585", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/d21b3605-038c-4dad-9543-8fd88b2e0585/encrypt/app_d21b3605-038c-4dad-9543-8fd88b2e0585.zip"}, {"guid"=>"59bba5f4-0888-4ca4-9e7a-9ea22146ae6b", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/59bba5f4-0888-4ca4-9e7a-9ea22146ae6b/encrypt/app_59bba5f4-0888-4ca4-9e7a-9ea22146ae6b.zip"}, {"guid"=>"6fb96c26-ca0f-46a0-a84e-7d72ecbcb934", "asset_type"=>"ContentAsset", "file_extension"=>"mp3", "key"=>"content_assets/6fb96c26-ca0f-46a0-a84e-7d72ecbcb934/original/ch1_pg8.mp3"}, {"guid"=>"ce64e635-bb00-4745-9119-292acfa5d62c", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/ce64e635-bb00-4745-9119-292acfa5d62c/encrypt/app_ce64e635-bb00-4745-9119-292acfa5d62c.zip"}, {"guid"=>"4927e4c4-1206-458d-9595-149de9845e80", "asset_type"=>"ContentAsset", "file_extension"=>"mp3", "key"=>"content_assets/4927e4c4-1206-458d-9595-149de9845e80/original/chap7_pg96.mp3"}, {"guid"=>"76f989a1-2496-42aa-b400-e904760f2ec3", "asset_type"=>"ContentAsset", "file_extension"=>"mp4", "key"=>"content_assets/76f989a1-2496-42aa-b400-e904760f2ec3/original/ch6_pg145_Properties_of_Pie_Charts.mp4"}, {"guid"=>"d35b31e3-09a0-4a6f-802e-7aa385d2198d", "asset_type"=>"ContentAsset", "file_extension"=>"json", "key"=>"content_assets/d35b31e3-09a0-4a6f-802e-7aa385d2198d/original/Class_5_Maths.json"}, {"guid"=>"26a5f539-ec5f-4858-9102-80d323670f5c", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/26a5f539-ec5f-4858-9102-80d323670f5c/encrypt/app_26a5f539-ec5f-4858-9102-80d323670f5c.zip"}, {"guid"=>"545c2c4f-41f8-45d6-9723-a80de62411e0", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/545c2c4f-41f8-45d6-9723-a80de62411e0/encrypt/app_545c2c4f-41f8-45d6-9723-a80de62411e0.zip"}, {"guid"=>"b683db40-803e-485a-8873-5cc6dfc3f05d", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/b683db40-803e-485a-8873-5cc6dfc3f05d/encrypt/app_b683db40-803e-485a-8873-5cc6dfc3f05d.zip"}, {"guid"=>"2c18f1b7-6974-48f4-be49-6a4e3bd3cf82", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/2c18f1b7-6974-48f4-be49-6a4e3bd3cf82/encrypt/app_2c18f1b7-6974-48f4-be49-6a4e3bd3cf82.zip"}, {"guid"=>"51f37831-a6b0-4d16-87e9-973eb88f5a29", "asset_type"=>"ContentAsset", "file_extension"=>"json", "key"=>"content_assets/51f37831-a6b0-4d16-87e9-973eb88f5a29/original/science.json"}, {"guid"=>"d4aae5b5-88f8-4bd6-8494-69908f391671", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/d4aae5b5-88f8-4bd6-8494-69908f391671/encrypt/app_d4aae5b5-88f8-4bd6-8494-69908f391671.zip"}, {"guid"=>"a9af9b01-c218-4bef-b3b7-a309ef340ed8", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/a9af9b01-c218-4bef-b3b7-a309ef340ed8/encrypt/app_a9af9b01-c218-4bef-b3b7-a309ef340ed8.zip"}, {"guid"=>"d9220fa6-e160-4ab8-b578-8eeaa6ace835", "asset_type"=>"ContentAsset", "file_extension"=>"mp3", "key"=>"content_assets/d9220fa6-e160-4ab8-b578-8eeaa6ace835/original/chap7_pg97.mp3"}, {"guid"=>"be14fb67-10b1-4d5e-9328-39fb210b4b52", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/be14fb67-10b1-4d5e-9328-39fb210b4b52/encrypt/app_be14fb67-10b1-4d5e-9328-39fb210b4b52.zip"}, {"guid"=>"ce0d9217-5599-495b-89b3-36ffba564409", "asset_type"=>"ContentAsset", "file_extension"=>"json", "key"=>"content_assets/ce0d9217-5599-495b-89b3-36ffba564409/original/Hindi.json"}, {"guid"=>"167d938e-2baa-405e-8ba5-66a069f60960", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/167d938e-2baa-405e-8ba5-66a069f60960/encrypt/app_167d938e-2baa-405e-8ba5-66a069f60960.zip"}, {"guid"=>"8c383b05-4269-45a3-a1d3-dcf3fc2976c3", "asset_type"=>"ContentAsset", "file_extension"=>"mp4", "key"=>"content_assets/8c383b05-4269-45a3-a1d3-dcf3fc2976c3/original/ch2_page19_AdditionOfLargeNumbers.mp4"}, {"guid"=>"2bf6d9fa-60f0-4ebe-9299-44d98389d774", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/2bf6d9fa-60f0-4ebe-9299-44d98389d774/encrypt/app_2bf6d9fa-60f0-4ebe-9299-44d98389d774.zip"}, {"guid"=>"d3364bac-99f3-4d85-b341-2c60f365fcc4", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/d3364bac-99f3-4d85-b341-2c60f365fcc4/encrypt/app_d3364bac-99f3-4d85-b341-2c60f365fcc4.zip"}, {"guid"=>"fd1f5c75-d47e-4cbd-bc44-96ee655303de", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/fd1f5c75-d47e-4cbd-bc44-96ee655303de/encrypt/app_fd1f5c75-d47e-4cbd-bc44-96ee655303de.zip"}, {"guid"=>"5ef4de47-7c33-43a7-9ba9-9fc7743f9d59", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/5ef4de47-7c33-43a7-9ba9-9fc7743f9d59/encrypt/app_5ef4de47-7c33-43a7-9ba9-9fc7743f9d59.zip"}, {"guid"=>"a925cc54-3898-4718-966d-9cd498041ed3", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/a925cc54-3898-4718-966d-9cd498041ed3/encrypt/app_a925cc54-3898-4718-966d-9cd498041ed3.zip"}, {"guid"=>"df1e725a-b942-4ee7-aa0c-9de9cf641db3", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/df1e725a-b942-4ee7-aa0c-9de9cf641db3/encrypt/app_df1e725a-b942-4ee7-aa0c-9de9cf641db3.zip"}, {"guid"=>"344fa6ea-7993-4e20-97b0-b6e32ea6b9fe", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/344fa6ea-7993-4e20-97b0-b6e32ea6b9fe/encrypt/app_344fa6ea-7993-4e20-97b0-b6e32ea6b9fe.zip"}, {"guid"=>"95865e60-14e0-4375-b549-2a10ed665b31", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/95865e60-14e0-4375-b549-2a10ed665b31/encrypt/app_95865e60-14e0-4375-b549-2a10ed665b31.zip"}, {"guid"=>"339d0287-13ed-4956-824d-883d70b6e6c0", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/339d0287-13ed-4956-824d-883d70b6e6c0/encrypt/app_339d0287-13ed-4956-824d-883d70b6e6c0.zip"}, {"guid"=>"3e1f45b0-03d2-423e-af98-e8f3aec64858", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/3e1f45b0-03d2-423e-af98-e8f3aec64858/encrypt/app_3e1f45b0-03d2-423e-af98-e8f3aec64858.zip"}, {"guid"=>"58c4956d-ed79-4125-b4ec-0982126a7769", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/58c4956d-ed79-4125-b4ec-0982126a7769/encrypt/app_58c4956d-ed79-4125-b4ec-0982126a7769.zip"}, {"guid"=>"c605482d-d3dc-4954-a2a6-333719d04be8", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/c605482d-d3dc-4954-a2a6-333719d04be8/encrypt/app_c605482d-d3dc-4954-a2a6-333719d04be8.zip"}, {"guid"=>"077a7894-3c97-489f-84d2-25a369124e6e", "asset_type"=>"ContentAsset", "file_extension"=>"pdf", "key"=>"content_assets/077a7894-3c97-489f-84d2-25a369124e6e/original/awarenessscience8.pdf"}, {"guid"=>"57ef6760-ac90-4ee6-96b8-9956a1cd859e", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/57ef6760-ac90-4ee6-96b8-9956a1cd859e/encrypt/app_57ef6760-ac90-4ee6-96b8-9956a1cd859e.zip"}, {"guid"=>"eea7ec99-15e0-44f6-8a1f-9ffaa0e3c91d", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/eea7ec99-15e0-44f6-8a1f-9ffaa0e3c91d/encrypt/app_eea7ec99-15e0-44f6-8a1f-9ffaa0e3c91d.zip"}, {"guid"=>"acc1f23b-2d1d-4be2-b94d-b46fc46f5256", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/acc1f23b-2d1d-4be2-b94d-b46fc46f5256/encrypt/app_acc1f23b-2d1d-4be2-b94d-b46fc46f5256.zip"}, {"guid"=>"12058d0c-1dcb-44f8-89d9-64bfa10c6c82", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/12058d0c-1dcb-44f8-89d9-64bfa10c6c82/encrypt/app_12058d0c-1dcb-44f8-89d9-64bfa10c6c82.zip"}, {"guid"=>"c15227da-90a7-4e57-9664-8f36129022b2", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/c15227da-90a7-4e57-9664-8f36129022b2/encrypt/app_c15227da-90a7-4e57-9664-8f36129022b2.zip"}, {"guid"=>"c7ef5c4b-d791-418a-bb38-4f79a8d15d04", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/c7ef5c4b-d791-418a-bb38-4f79a8d15d04/encrypt/app_c7ef5c4b-d791-418a-bb38-4f79a8d15d04.zip"}, {"guid"=>"551a2811-2eae-4f17-abda-f97a53850819", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/551a2811-2eae-4f17-abda-f97a53850819/encrypt/app_551a2811-2eae-4f17-abda-f97a53850819.zip"}, {"guid"=>"36b298f9-7cda-41bf-aaea-661a87d3cef7", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/36b298f9-7cda-41bf-aaea-661a87d3cef7/encrypt/app_36b298f9-7cda-41bf-aaea-661a87d3cef7.zip"}, {"guid"=>"c6aa4aaa-6c52-4022-8bed-b79c0218b283", "asset_type"=>"ContentAsset", "file_extension"=>"mp4", "key"=>"content_assets/c6aa4aaa-6c52-4022-8bed-b79c0218b283/original/GR_4_Estimation_of_Sum_Difference_Product_and_Quotient_v3_1.mp4"}, {"guid"=>"a586a49e-b86a-477c-aeb6-770cfac9646c", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/a586a49e-b86a-477c-aeb6-770cfac9646c/encrypt/app_a586a49e-b86a-477c-aeb6-770cfac9646c.zip"}, {"guid"=>"dbb37e9c-823a-477a-ac6a-79bd55f32f12", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/dbb37e9c-823a-477a-ac6a-79bd55f32f12/encrypt/app_dbb37e9c-823a-477a-ac6a-79bd55f32f12.zip"}, {"guid"=>"81f5e47c-4df3-4cfc-b05a-d2f8070cfe3b", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/81f5e47c-4df3-4cfc-b05a-d2f8070cfe3b/encrypt/app_81f5e47c-4df3-4cfc-b05a-d2f8070cfe3b.zip"}, {"guid"=>"66c9de38-080e-48f4-9bd8-b4ad1bfdc088", "asset_type"=>"ContentAsset", "file_extension"=>"mp3", "key"=>"content_assets/66c9de38-080e-48f4-9bd8-b4ad1bfdc088/original/ch1_pg11.mp3"}, {"guid"=>"03f9d146-17e9-436c-9902-436b339912f9", "asset_type"=>"ContentAsset", "file_extension"=>"json", "key"=>"content_assets/03f9d146-17e9-436c-9902-436b339912f9/original/dictionary.json"}, {"guid"=>"73a73b6d-46ee-4925-bfdb-d7eaf1b8f0de", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/73a73b6d-46ee-4925-bfdb-d7eaf1b8f0de/encrypt/app_73a73b6d-46ee-4925-bfdb-d7eaf1b8f0de.zip"}, {"guid"=>"07f6158b-bff9-42b9-a5a3-3a7e75ab3c1b", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/07f6158b-bff9-42b9-a5a3-3a7e75ab3c1b/encrypt/app_07f6158b-bff9-42b9-a5a3-3a7e75ab3c1b.zip"}, {"guid"=>"b1841555-017d-48e7-8565-05a750c95a33", "asset_type"=>"ContentAsset", "file_extension"=>"mp3", "key"=>"content_assets/b1841555-017d-48e7-8565-05a750c95a33/original/Ch_1__pg3.mp3"}, {"guid"=>"ae30565e-aaca-4ffc-8efa-4a36493058e3", "asset_type"=>"ContentAsset", "file_extension"=>"mp4", "key"=>"content_assets/ae30565e-aaca-4ffc-8efa-4a36493058e3/original/05_Reflex_Arc_pg90.mp4"}, {"guid"=>"2139eea4-41b1-4b74-9c11-418afe2f0274", "asset_type"=>"ContentAsset", "file_extension"=>"mp4", "key"=>"content_assets/2139eea4-41b1-4b74-9c11-418afe2f0274/original/04_The_Human_Brain_pg86.mp4"}, {"guid"=>"582ab9f9-6380-4e2e-84c4-22a4b729d9bb", "asset_type"=>"ContentAsset", "file_extension"=>"mp4", "key"=>"content_assets/582ab9f9-6380-4e2e-84c4-22a4b729d9bb/original/26_MM_MATH_GR5_TallyMarksAndLineGraphs.mp4"}, {"guid"=>"7eef1a88-d73f-4731-9e85-98fb1968aa30", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/7eef1a88-d73f-4731-9e85-98fb1968aa30/encrypt/app_7eef1a88-d73f-4731-9e85-98fb1968aa30.zip"}, {"guid"=>"131fcfa8-95b7-4538-a593-7f5dba60aa9f", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/131fcfa8-95b7-4538-a593-7f5dba60aa9f/encrypt/app_131fcfa8-95b7-4538-a593-7f5dba60aa9f.zip"}, {"guid"=>"7e618b66-e04c-4f7f-8c16-8f1cdc3f0af0", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/7e618b66-e04c-4f7f-8c16-8f1cdc3f0af0/encrypt/app_7e618b66-e04c-4f7f-8c16-8f1cdc3f0af0.zip"}, {"guid"=>"35d103f6-1ae0-4b40-b88f-d9266a39bbfe", "asset_type"=>"ContentAsset", "file_extension"=>"json", "key"=>"content_assets/35d103f6-1ae0-4b40-b88f-d9266a39bbfe/original/Class_4_Science.json"}, {"guid"=>"473fdefd-c630-4261-844e-33907065eb7c", "asset_type"=>"ContentAsset", "file_extension"=>"mp4", "key"=>"content_assets/473fdefd-c630-4261-844e-33907065eb7c/original/ch6_pg144_Introduction.mp4"}, {"guid"=>"54d7aa9f-e247-43ee-bdb9-2dec467ba7f7", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/54d7aa9f-e247-43ee-bdb9-2dec467ba7f7/encrypt/app_54d7aa9f-e247-43ee-bdb9-2dec467ba7f7.zip"}, {"guid"=>"3409aa65-1394-458a-901f-3bd6e30132c9", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/3409aa65-1394-458a-901f-3bd6e30132c9/original/0c0ddd76-fdeb-49f1-9343-f90480a83ee4.zip"}, {"guid"=>"320f0457-f49c-42f7-9ffc-6eeb4b0a5c30", "asset_type"=>"ContentAsset", "file_extension"=>"json", "key"=>"content_assets/320f0457-f49c-42f7-9ffc-6eeb4b0a5c30/original/Class_4_Maths.json"}, {"guid"=>"d9c933cd-1ae1-47eb-8b37-867dc6f62194", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/d9c933cd-1ae1-47eb-8b37-867dc6f62194/encrypt/app_d9c933cd-1ae1-47eb-8b37-867dc6f62194.zip"}, {"guid"=>"12cb1d45-a3f1-4e27-bc0a-f78c5d204a35", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/12cb1d45-a3f1-4e27-bc0a-f78c5d204a35/encrypt/app_12cb1d45-a3f1-4e27-bc0a-f78c5d204a35.zip"}, {"guid"=>"7da98eef-70f4-4fb4-9e60-6bb1af2c8aa5", "asset_type"=>"ContentAsset", "file_extension"=>"mp4", "key"=>"content_assets/7da98eef-70f4-4fb4-9e60-6bb1af2c8aa5/original/Ch6_pg142_Pg_231.mp4"}, {"guid"=>"32a0bd7b-744b-453d-9d34-a92ca0a2a630", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/32a0bd7b-744b-453d-9d34-a92ca0a2a630/encrypt/app_32a0bd7b-744b-453d-9d34-a92ca0a2a630.zip"}, {"guid"=>"50e46466-ce3e-46de-9f61-e86d5f36e601", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/50e46466-ce3e-46de-9f61-e86d5f36e601/encrypt/app_50e46466-ce3e-46de-9f61-e86d5f36e601.zip"}, {"guid"=>"3eff73ed-71d2-4062-b807-3abfcb4ac2c1", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/3eff73ed-71d2-4062-b807-3abfcb4ac2c1/encrypt/app_3eff73ed-71d2-4062-b807-3abfcb4ac2c1.zip"}, {"guid"=>"01fa02f6-b3c9-4921-b4fa-62a590181ff3", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/01fa02f6-b3c9-4921-b4fa-62a590181ff3/encrypt/app_01fa02f6-b3c9-4921-b4fa-62a590181ff3.zip"}, {"guid"=>"67d34d61-cddf-4bcd-81f2-434581701b0d", "asset_type"=>"ContentAsset", "file_extension"=>"mp3", "key"=>"content_assets/67d34d61-cddf-4bcd-81f2-434581701b0d/original/chap7_pg95.mp3"}, {"guid"=>"bf7f58dc-0dc9-4c93-894c-8947d304e989", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/bf7f58dc-0dc9-4c93-894c-8947d304e989/encrypt/app_bf7f58dc-0dc9-4c93-894c-8947d304e989.zip"}, {"guid"=>"3595b4e0-49b9-4e28-b2be-130358c7344d", "asset_type"=>"ContentAsset", "file_extension"=>"mp3", "key"=>"content_assets/3595b4e0-49b9-4e28-b2be-130358c7344d/original/Ch_1__pg1.mp3"}, {"guid"=>"3899c978-b911-45e6-9b53-ab20ef24e65d", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/3899c978-b911-45e6-9b53-ab20ef24e65d/encrypt/app_3899c978-b911-45e6-9b53-ab20ef24e65d.zip"}, {"guid"=>"7bb609b5-9387-4d42-bdc4-14b277e43b85", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/7bb609b5-9387-4d42-bdc4-14b277e43b85/encrypt/app_7bb609b5-9387-4d42-bdc4-14b277e43b85.zip"}, {"guid"=>"7da136f1-d302-4e4b-9214-3ecab6ba6114", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/7da136f1-d302-4e4b-9214-3ecab6ba6114/encrypt/app_7da136f1-d302-4e4b-9214-3ecab6ba6114.zip"}, {"guid"=>"173737ae-21ab-498d-8ac4-0a107a2e1bda", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/173737ae-21ab-498d-8ac4-0a107a2e1bda/encrypt/app_173737ae-21ab-498d-8ac4-0a107a2e1bda.zip"}, {"guid"=>"1954ae60-6e73-46c3-916e-ead38ca3f9d7", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/1954ae60-6e73-46c3-916e-ead38ca3f9d7/encrypt/app_1954ae60-6e73-46c3-916e-ead38ca3f9d7.zip"}, {"guid"=>"1757906c-3e40-498e-b628-6bc18e335730", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/1757906c-3e40-498e-b628-6bc18e335730/encrypt/app_1757906c-3e40-498e-b628-6bc18e335730.zip"}, {"guid"=>"5f370ddf-8cd7-4795-9f59-acd510f61908", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/5f370ddf-8cd7-4795-9f59-acd510f61908/encrypt/app_5f370ddf-8cd7-4795-9f59-acd510f61908.zip"}, {"guid"=>"e7f1f763-3391-4663-92cc-809f0b0d1a2b", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/e7f1f763-3391-4663-92cc-809f0b0d1a2b/encrypt/app_e7f1f763-3391-4663-92cc-809f0b0d1a2b.zip"}, {"guid"=>"41342416-d9a2-411c-a940-f97a28bee4c9", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/41342416-d9a2-411c-a940-f97a28bee4c9/encrypt/app_41342416-d9a2-411c-a940-f97a28bee4c9.zip"}, {"guid"=>"3d48ed64-7227-461e-9c80-3e40827bb8d8", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/3d48ed64-7227-461e-9c80-3e40827bb8d8/encrypt/app_3d48ed64-7227-461e-9c80-3e40827bb8d8.zip"}, {"guid"=>"2bf032ff-2078-450b-b749-67862461338e", "asset_type"=>"ContentAsset", "file_extension"=>"json", "key"=>"content_assets/2bf032ff-2078-450b-b749-67862461338e/original/Social.json"}, {"guid"=>"aded6734-ae4d-451c-85e7-25a65bc756aa", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/aded6734-ae4d-451c-85e7-25a65bc756aa/encrypt/app_aded6734-ae4d-451c-85e7-25a65bc756aa.zip"}, {"guid"=>"e8a3e9d7-500d-4ba4-ac8f-c338477b2dd9", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/e8a3e9d7-500d-4ba4-ac8f-c338477b2dd9/encrypt/app_e8a3e9d7-500d-4ba4-ac8f-c338477b2dd9.zip"}, {"guid"=>"0064dd70-26ae-4822-b82b-8ce8998cbc5a", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/0064dd70-26ae-4822-b82b-8ce8998cbc5a/encrypt/app_0064dd70-26ae-4822-b82b-8ce8998cbc5a.zip"}, {"guid"=>"bb58c6be-366f-43ee-b5c7-6751ed993016", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/bb58c6be-366f-43ee-b5c7-6751ed993016/encrypt/app_bb58c6be-366f-43ee-b5c7-6751ed993016.zip"}, {"guid"=>"63453da3-fc85-4341-ba47-bbd42090f569", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/63453da3-fc85-4341-ba47-bbd42090f569/encrypt/app_63453da3-fc85-4341-ba47-bbd42090f569.zip"}, {"guid"=>"51ec5150-fb84-4f07-9357-8a8899c1951b", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/51ec5150-fb84-4f07-9357-8a8899c1951b/encrypt/app_51ec5150-fb84-4f07-9357-8a8899c1951b.zip"}, {"guid"=>"5988ea0e-c091-4a0d-8c18-a2898af95c31", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/5988ea0e-c091-4a0d-8c18-a2898af95c31/encrypt/app_5988ea0e-c091-4a0d-8c18-a2898af95c31.zip"}, {"guid"=>"b358549f-cb6f-4ca7-b8a7-8e8d2962c541", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/b358549f-cb6f-4ca7-b8a7-8e8d2962c541/encrypt/app_b358549f-cb6f-4ca7-b8a7-8e8d2962c541.zip"}, {"guid"=>"74810c6d-655e-4527-8e24-b7f3c3d934c9", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/74810c6d-655e-4527-8e24-b7f3c3d934c9/encrypt/app_74810c6d-655e-4527-8e24-b7f3c3d934c9.zip"}, {"guid"=>"03052603-0702-4cdb-837d-d6ad03c4308c", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/03052603-0702-4cdb-837d-d6ad03c4308c/encrypt/app_03052603-0702-4cdb-837d-d6ad03c4308c.zip"}, {"guid"=>"a4ecf6a1-8410-41f8-bcee-ceb1e89bf8f7", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/a4ecf6a1-8410-41f8-bcee-ceb1e89bf8f7/encrypt/app_a4ecf6a1-8410-41f8-bcee-ceb1e89bf8f7.zip"}, {"guid"=>"cbcf306f-bddd-493c-866f-624d623aa54a", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/cbcf306f-bddd-493c-866f-624d623aa54a/encrypt/app_cbcf306f-bddd-493c-866f-624d623aa54a.zip"}, {"guid"=>"d400a1d9-85a8-46c2-9da5-46a150622364", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/d400a1d9-85a8-46c2-9da5-46a150622364/encrypt/app_d400a1d9-85a8-46c2-9da5-46a150622364.zip"}, {"guid"=>"1abccfd4-b837-4fd7-b550-a2a6aa3c33eb", "asset_type"=>"ContentAsset", "file_extension"=>"mp3", "key"=>"content_assets/1abccfd4-b837-4fd7-b550-a2a6aa3c33eb/original/ch1_pg9.mp3"}, {"guid"=>"575ff77b-d35a-4a6f-b720-647ddb18711b", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/575ff77b-d35a-4a6f-b720-647ddb18711b/encrypt/app_575ff77b-d35a-4a6f-b720-647ddb18711b.zip"}, {"guid"=>"852d6b08-9794-4753-a012-4d33096c2495", "asset_type"=>"ContentAsset", "file_extension"=>"json", "key"=>"content_assets/852d6b08-9794-4753-a012-4d33096c2495/original/computerscience.json"}, {"guid"=>"a5c96cf3-aced-4320-b50b-96a197b4a4c2", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/a5c96cf3-aced-4320-b50b-96a197b4a4c2/encrypt/app_a5c96cf3-aced-4320-b50b-96a197b4a4c2.zip"}, {"guid"=>"f4c34c00-b2b9-48f0-bef7-d98c7b683829", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/f4c34c00-b2b9-48f0-bef7-d98c7b683829/encrypt/app_f4c34c00-b2b9-48f0-bef7-d98c7b683829.zip"}, {"guid"=>"3defa8f2-695f-475e-b8c8-69aa79aa7b71", "asset_type"=>"ContentAsset", "file_extension"=>"mp3", "key"=>"content_assets/3defa8f2-695f-475e-b8c8-69aa79aa7b71/original/chap7_pg101.mp3"}, {"guid"=>"1ddedccf-d103-4509-9d5c-6af193b7ad14", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/1ddedccf-d103-4509-9d5c-6af193b7ad14/encrypt/app_1ddedccf-d103-4509-9d5c-6af193b7ad14.zip"}, {"guid"=>"06f107a2-dde1-4db7-a800-b43ebc7851da", "asset_type"=>"ContentAsset", "file_extension"=>"mp3", "key"=>"content_assets/06f107a2-dde1-4db7-a800-b43ebc7851da/original/ch1_pg13.mp3"}, {"guid"=>"8e188e52-b7c7-4758-a925-472e551cc6ae", "asset_type"=>"ContentAsset", "file_extension"=>"mp3", "key"=>"content_assets/8e188e52-b7c7-4758-a925-472e551cc6ae/original/Chapter_6.mp3"}, {"guid"=>"91c93761-f534-42e4-809d-efe04e71f22f", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/91c93761-f534-42e4-809d-efe04e71f22f/encrypt/app_91c93761-f534-42e4-809d-efe04e71f22f.zip"}, {"guid"=>"5157ed17-f39b-44bb-926f-26ea79aef865", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/5157ed17-f39b-44bb-926f-26ea79aef865/encrypt/app_5157ed17-f39b-44bb-926f-26ea79aef865.zip"}, {"guid"=>"f5ac44f0-3184-4502-982e-2d52900cde99", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/f5ac44f0-3184-4502-982e-2d52900cde99/encrypt/app_f5ac44f0-3184-4502-982e-2d52900cde99.zip"}, {"guid"=>"4a2fde71-092e-441a-8a9f-decb32b6d863", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/4a2fde71-092e-441a-8a9f-decb32b6d863/encrypt/app_4a2fde71-092e-441a-8a9f-decb32b6d863.zip"}, {"guid"=>"09c59f11-ed12-4b78-9563-ba57e169cd72", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/09c59f11-ed12-4b78-9563-ba57e169cd72/encrypt/app_09c59f11-ed12-4b78-9563-ba57e169cd72.zip"}, {"guid"=>"16a47aa8-aca1-41a3-97b5-08c6d935926a", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/16a47aa8-aca1-41a3-97b5-08c6d935926a/encrypt/app_16a47aa8-aca1-41a3-97b5-08c6d935926a.zip"}, {"guid"=>"8cc29c54-5e05-4a70-8b0f-4d833aeff7db", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/8cc29c54-5e05-4a70-8b0f-4d833aeff7db/encrypt/app_8cc29c54-5e05-4a70-8b0f-4d833aeff7db.zip"}, {"guid"=>"5cf87e27-1f68-417c-878b-abfa1d65a04a", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/5cf87e27-1f68-417c-878b-abfa1d65a04a/encrypt/app_5cf87e27-1f68-417c-878b-abfa1d65a04a.zip"}, {"guid"=>"4c5502cf-8c2a-4850-8cc0-00bbfdbeefdf", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/4c5502cf-8c2a-4850-8cc0-00bbfdbeefdf/encrypt/app_4c5502cf-8c2a-4850-8cc0-00bbfdbeefdf.zip"}, {"guid"=>"86a18810-e6da-48f6-b986-239beaab913c", "asset_type"=>"ContentAsset", "file_extension"=>"mp3", "key"=>"content_assets/86a18810-e6da-48f6-b986-239beaab913c/original/chap1_pg7.mp3"}, {"guid"=>"9269fcb4-ae72-4c75-9cae-4479488b9688", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/9269fcb4-ae72-4c75-9cae-4479488b9688/encrypt/app_9269fcb4-ae72-4c75-9cae-4479488b9688.zip"}, {"guid"=>"c674975e-3e61-4bee-ac1e-823a50f15ec4", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/c674975e-3e61-4bee-ac1e-823a50f15ec4/encrypt/app_c674975e-3e61-4bee-ac1e-823a50f15ec4.zip"}, {"guid"=>"4aa6547b-f138-4531-a666-2240baa43cd9", "asset_type"=>"ContentAsset", "file_extension"=>"json", "key"=>"content_assets/4aa6547b-f138-4531-a666-2240baa43cd9/original/Atlas.json"}, {"guid"=>"a1ad334b-3887-48d7-b611-8df493f48b71", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/a1ad334b-3887-48d7-b611-8df493f48b71/encrypt/app_a1ad334b-3887-48d7-b611-8df493f48b71.zip"}, {"guid"=>"29e05d08-3e2f-4ea2-84b9-11717a4c6065", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/29e05d08-3e2f-4ea2-84b9-11717a4c6065/encrypt/app_29e05d08-3e2f-4ea2-84b9-11717a4c6065.zip"}, {"guid"=>"ca4c385c-1189-4860-a2bb-32005988a2ce", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/ca4c385c-1189-4860-a2bb-32005988a2ce/encrypt/app_ca4c385c-1189-4860-a2bb-32005988a2ce.zip"}, {"guid"=>"b663a51d-0cf9-402d-8ccc-4dc81581e68b", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/b663a51d-0cf9-402d-8ccc-4dc81581e68b/encrypt/app_b663a51d-0cf9-402d-8ccc-4dc81581e68b.zip"}, {"guid"=>"402364dc-6955-41c8-8785-93713634e3df", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/402364dc-6955-41c8-8785-93713634e3df/encrypt/app_402364dc-6955-41c8-8785-93713634e3df.zip"}, {"guid"=>"4b66f794-b94b-42de-a39a-a02e5f48091e", "asset_type"=>"ContentAsset", "file_extension"=>"mp3", "key"=>"content_assets/4b66f794-b94b-42de-a39a-a02e5f48091e/original/chap7_pg103.mp3"}, {"guid"=>"1ef75854-fa17-4b69-a095-9d7a643e1be0", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/1ef75854-fa17-4b69-a095-9d7a643e1be0/encrypt/app_1ef75854-fa17-4b69-a095-9d7a643e1be0.zip"}, {"guid"=>"08a7458b-ef8c-44cb-8a28-a320d6511faa", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/08a7458b-ef8c-44cb-8a28-a320d6511faa/encrypt/app_08a7458b-ef8c-44cb-8a28-a320d6511faa.zip"}, {"guid"=>"05eba33e-98d7-4be7-8ac6-38eb8b5edd42", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/05eba33e-98d7-4be7-8ac6-38eb8b5edd42/encrypt/app_05eba33e-98d7-4be7-8ac6-38eb8b5edd42.zip"}, {"guid"=>"a6a624e5-4181-41a7-8d35-a22c75e78852", "asset_type"=>"ContentAsset", "file_extension"=>"mp3", "key"=>"content_assets/a6a624e5-4181-41a7-8d35-a22c75e78852/original/ch1_pg14.mp3"}, {"guid"=>"ff1eb14b-1cd4-4af3-868f-48587684570d", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/ff1eb14b-1cd4-4af3-868f-48587684570d/encrypt/app_ff1eb14b-1cd4-4af3-868f-48587684570d.zip"}, {"guid"=>"1d13c2ec-503f-45e0-a4a2-a34b895bf26e", "asset_type"=>"ContentAsset", "file_extension"=>"json", "key"=>"content_assets/1d13c2ec-503f-45e0-a4a2-a34b895bf26e/original/Class_5_English.json"}, {"guid"=>"e5b93d5b-b6f6-4071-8ff5-1b1e76716b45", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/e5b93d5b-b6f6-4071-8ff5-1b1e76716b45/encrypt/app_e5b93d5b-b6f6-4071-8ff5-1b1e76716b45.zip"}, {"guid"=>"0c0ddd76-fdeb-49f1-9343-f90480a83ee4", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/0c0ddd76-fdeb-49f1-9343-f90480a83ee4/original/0c0ddd76-fdeb-49f1-9343-f90480a83ee4.zip"}, {"guid"=>"dbbacf8f-379b-463d-bd34-19064eb11a47", "asset_type"=>"ContentAsset", "file_extension"=>"mp4", "key"=>"content_assets/dbbacf8f-379b-463d-bd34-19064eb11a47/original/ch2_page27_Multiplication.mp4"}, {"guid"=>"40e9026a-4ef3-44d0-ad6a-46a6cc5d0c4e", "asset_type"=>"ContentAsset", "file_extension"=>"json", "key"=>"content_assets/40e9026a-4ef3-44d0-ad6a-46a6cc5d0c4e/original/Class_4_English.json"}, {"guid"=>"801f1ce2-0957-4fca-b7eb-97d6f68dd1a5", "asset_type"=>"ContentAsset", "file_extension"=>"mp4", "key"=>"content_assets/801f1ce2-0957-4fca-b7eb-97d6f68dd1a5/original/Pg_31.mp4"}, {"guid"=>"6b92b043-56c6-4e9b-a567-aaf9914c6969", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/6b92b043-56c6-4e9b-a567-aaf9914c6969/encrypt/app_6b92b043-56c6-4e9b-a567-aaf9914c6969.zip"}, {"guid"=>"e03a047e-ba36-4ee3-ad3f-578ca873c740", "asset_type"=>"ContentAsset", "file_extension"=>"mp3", "key"=>"content_assets/e03a047e-ba36-4ee3-ad3f-578ca873c740/original/ch1_pg6.mp3"}, {"guid"=>"3e9e6dad-5e47-4786-aaae-5fb97e28c94b", "asset_type"=>"ContentAsset", "file_extension"=>"mp4", "key"=>"content_assets/3e9e6dad-5e47-4786-aaae-5fb97e28c94b/original/Pg_33.mp4"}, {"guid"=>"cb41e51f-005f-4a04-94d1-088f4fae800d", "asset_type"=>"ContentAsset", "file_extension"=>"json", "key"=>"content_assets/cb41e51f-005f-4a04-94d1-088f4fae800d/original/english.json"}, {"guid"=>"4cb89f71-77d3-456a-94b7-d0049c5d7043", "asset_type"=>"ContentAsset", "file_extension"=>"mp3", "key"=>"content_assets/4cb89f71-77d3-456a-94b7-d0049c5d7043/original/Ch_1__pg3.mp3"}, {"guid"=>"2741c1f0-88c2-4e2d-bfcc-e6f5920c31cc", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/2741c1f0-88c2-4e2d-bfcc-e6f5920c31cc/encrypt/app_2741c1f0-88c2-4e2d-bfcc-e6f5920c31cc.zip"}, {"guid"=>"2da5bfe1-5d99-4762-93fe-7884baa4e12c", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/2da5bfe1-5d99-4762-93fe-7884baa4e12c/encrypt/app_2da5bfe1-5d99-4762-93fe-7884baa4e12c.zip"}, {"guid"=>"52baee90-5a45-4ce0-8750-37a567e69486", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/52baee90-5a45-4ce0-8750-37a567e69486/encrypt/app_52baee90-5a45-4ce0-8750-37a567e69486.zip"}, {"guid"=>"3946f425-791b-45da-bb86-14429e6532a3", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/3946f425-791b-45da-bb86-14429e6532a3/encrypt/app_3946f425-791b-45da-bb86-14429e6532a3.zip"}, {"guid"=>"e2f07b2c-e3ea-487f-9ba1-f85b95056dd0", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/e2f07b2c-e3ea-487f-9ba1-f85b95056dd0/encrypt/app_e2f07b2c-e3ea-487f-9ba1-f85b95056dd0.zip"}, {"guid"=>"8b003cd6-2119-4a75-9659-a55699cce523", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/8b003cd6-2119-4a75-9659-a55699cce523/encrypt/app_8b003cd6-2119-4a75-9659-a55699cce523.zip"}, {"guid"=>"89aa08ac-d400-49c8-aea4-ae41364fbb30", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/89aa08ac-d400-49c8-aea4-ae41364fbb30/encrypt/app_89aa08ac-d400-49c8-aea4-ae41364fbb30.zip"}, {"guid"=>"5fb8208a-3ae0-43a1-9790-1a22af62c836", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/5fb8208a-3ae0-43a1-9790-1a22af62c836/encrypt/app_5fb8208a-3ae0-43a1-9790-1a22af62c836.zip"}, {"guid"=>"189d4946-ed04-4bdb-81d8-afce95f58018", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/189d4946-ed04-4bdb-81d8-afce95f58018/encrypt/app_189d4946-ed04-4bdb-81d8-afce95f58018.zip"}, {"guid"=>"717ec5f5-82d9-43fc-8026-2a98268aa340", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/717ec5f5-82d9-43fc-8026-2a98268aa340/encrypt/app_717ec5f5-82d9-43fc-8026-2a98268aa340.zip"}, {"guid"=>"e0c78f86-9246-471a-9334-eb744f031194", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/e0c78f86-9246-471a-9334-eb744f031194/encrypt/app_e0c78f86-9246-471a-9334-eb744f031194.zip"}, {"guid"=>"c733477c-afb0-41fd-bd67-fd36649227d8", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/c733477c-afb0-41fd-bd67-fd36649227d8/encrypt/app_c733477c-afb0-41fd-bd67-fd36649227d8.zip"}, {"guid"=>"dfec7fda-2b27-4262-9f44-f0aad4038670", "asset_type"=>"ContentAsset", "file_extension"=>"mp3", "key"=>"content_assets/dfec7fda-2b27-4262-9f44-f0aad4038670/original/ch1_pg7.mp3"}, {"guid"=>"e357bb8f-8bf2-42a6-abbd-453a3f2ff13b", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/e357bb8f-8bf2-42a6-abbd-453a3f2ff13b/encrypt/app_e357bb8f-8bf2-42a6-abbd-453a3f2ff13b.zip"}, {"guid"=>"c2383f02-3e0b-413d-b2ba-58b40c899208", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/c2383f02-3e0b-413d-b2ba-58b40c899208/encrypt/app_c2383f02-3e0b-413d-b2ba-58b40c899208.zip"}, {"guid"=>"aa50abb5-6e0f-4fbb-bb4b-ef764468e414", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/aa50abb5-6e0f-4fbb-bb4b-ef764468e414/encrypt/app_aa50abb5-6e0f-4fbb-bb4b-ef764468e414.zip"}, {"guid"=>"98de0b94-1ce3-46a9-96f8-7a42ddf6f0eb", "asset_type"=>"ContentAsset", "file_extension"=>"mp4", "key"=>"content_assets/98de0b94-1ce3-46a9-96f8-7a42ddf6f0eb/original/ch7_pg94_Nervous_System.mp4"}, {"guid"=>"754bac24-9459-4db9-b184-fba70fa3f517", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/754bac24-9459-4db9-b184-fba70fa3f517/encrypt/app_754bac24-9459-4db9-b184-fba70fa3f517.zip"}, {"guid"=>"ea17935b-6153-4689-84c1-9ed0433eef8d", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/ea17935b-6153-4689-84c1-9ed0433eef8d/encrypt/app_ea17935b-6153-4689-84c1-9ed0433eef8d.zip"}, {"guid"=>"3acceba5-3b72-4e79-93ef-afd04303cfcd", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/3acceba5-3b72-4e79-93ef-afd04303cfcd/encrypt/app_3acceba5-3b72-4e79-93ef-afd04303cfcd.zip"}, {"guid"=>"9333ecd4-44c1-40c5-8cba-29cd0a7aed78", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/9333ecd4-44c1-40c5-8cba-29cd0a7aed78/encrypt/app_9333ecd4-44c1-40c5-8cba-29cd0a7aed78.zip"}, {"guid"=>"00717218-5c35-4b57-9cc4-c39499b1e024", "asset_type"=>"ContentAsset", "file_extension"=>"mp3", "key"=>"content_assets/00717218-5c35-4b57-9cc4-c39499b1e024/original/chap7_pg94.mp3"}, {"guid"=>"aedf6087-25a0-4bc1-a756-d6f26e6b3ffe", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/aedf6087-25a0-4bc1-a756-d6f26e6b3ffe/encrypt/app_aedf6087-25a0-4bc1-a756-d6f26e6b3ffe.zip"}, {"guid"=>"e606012e-c7bd-4af0-b0d5-c3447e136b72", "asset_type"=>"ContentAsset", "file_extension"=>"mp3", "key"=>"content_assets/e606012e-c7bd-4af0-b0d5-c3447e136b72/original/chap7_pg102.mp3"}, {"guid"=>"1f3cf7b0-5347-40ed-95c0-ab9630c78d67", "asset_type"=>"ContentAsset", "file_extension"=>"mp4", "key"=>"content_assets/1f3cf7b0-5347-40ed-95c0-ab9630c78d67/original/ch1_pg6_Plant_Make_Food.mp4"}, {"guid"=>"dc39b1d2-f58a-4f21-9e3d-7702446e0e88", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/dc39b1d2-f58a-4f21-9e3d-7702446e0e88/encrypt/app_dc39b1d2-f58a-4f21-9e3d-7702446e0e88.zip"}, {"guid"=>"4223d95f-71a2-4168-ac7a-06150357942b", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/4223d95f-71a2-4168-ac7a-06150357942b/encrypt/app_4223d95f-71a2-4168-ac7a-06150357942b.zip"}, {"guid"=>"0faea5cf-569f-432c-b3f5-6ce53b272f34", "asset_type"=>"ContentAsset", "file_extension"=>"mp3", "key"=>"content_assets/0faea5cf-569f-432c-b3f5-6ce53b272f34/original/chap1_pg6.mp3"}, {"guid"=>"65ebfd85-d9e5-43aa-8494-3807c49a1c52", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/65ebfd85-d9e5-43aa-8494-3807c49a1c52/encrypt/app_65ebfd85-d9e5-43aa-8494-3807c49a1c52.zip"}, {"guid"=>"ec91bd00-96ca-4225-8e6b-74065dba85bb", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/ec91bd00-96ca-4225-8e6b-74065dba85bb/encrypt/app_ec91bd00-96ca-4225-8e6b-74065dba85bb.zip"}, {"guid"=>"ed651bd5-95ad-4d43-bf8c-1955426d241b", "asset_type"=>"ContentAsset", "file_extension"=>"mp4", "key"=>"content_assets/ed651bd5-95ad-4d43-bf8c-1955426d241b/original/ch7_pg98_Nervous_System_The_Sense_Organs.mp4"}, {"guid"=>"be9229bf-99b8-45b6-8726-d69463bdf6f5", "asset_type"=>"ContentAsset", "file_extension"=>"json", "key"=>"content_assets/be9229bf-99b8-45b6-8726-d69463bdf6f5/original/maths.json"}, {"guid"=>"89eefc30-653f-48b6-8757-2b30b699abf8", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/89eefc30-653f-48b6-8757-2b30b699abf8/encrypt/app_89eefc30-653f-48b6-8757-2b30b699abf8.zip"}, {"guid"=>"677ee721-793d-4222-8452-d7c5b3f24a81", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/677ee721-793d-4222-8452-d7c5b3f24a81/encrypt/app_677ee721-793d-4222-8452-d7c5b3f24a81.zip"}, {"guid"=>"abc80593-2c13-4a37-a1cf-445bef945b13", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/abc80593-2c13-4a37-a1cf-445bef945b13/encrypt/app_abc80593-2c13-4a37-a1cf-445bef945b13.zip"}, {"guid"=>"99818ece-9c79-4e9f-92c4-9c2bbe19e41c", "asset_type"=>"ContentAsset", "file_extension"=>"mp3", "key"=>"content_assets/99818ece-9c79-4e9f-92c4-9c2bbe19e41c/original/Ch_1__pg2.mp3"}, {"guid"=>"ecb0c90e-5671-46a4-afcc-30d0df00b3d2", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/ecb0c90e-5671-46a4-afcc-30d0df00b3d2/encrypt/app_ecb0c90e-5671-46a4-afcc-30d0df00b3d2.zip"}, {"guid"=>"f505b514-b8cb-41a2-9f9b-74c850e5d701", "asset_type"=>"ContentAsset", "file_extension"=>"json", "key"=>"content_assets/f505b514-b8cb-41a2-9f9b-74c850e5d701/original/Class_5_Science.json"}, {"guid"=>"9ff933a5-a6e9-464f-9554-d2c594c951b0", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/9ff933a5-a6e9-464f-9554-d2c594c951b0/encrypt/app_9ff933a5-a6e9-464f-9554-d2c594c951b0.zip"}, {"guid"=>"b0dc5dcd-d1eb-426c-97f4-83869191644e", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/b0dc5dcd-d1eb-426c-97f4-83869191644e/encrypt/app_b0dc5dcd-d1eb-426c-97f4-83869191644e.zip"}, {"guid"=>"7c71d439-8daf-45ef-9d73-5a093dd5a38b", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/7c71d439-8daf-45ef-9d73-5a093dd5a38b/encrypt/app_7c71d439-8daf-45ef-9d73-5a093dd5a38b.zip"}, {"guid"=>"d2a6a9e8-87a9-4069-b830-aeb7efa680c6", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/d2a6a9e8-87a9-4069-b830-aeb7efa680c6/encrypt/app_d2a6a9e8-87a9-4069-b830-aeb7efa680c6.zip"}, {"guid"=>"1bd687a4-cb1e-487e-831f-ac607b99a0b3", "asset_type"=>"ContentAsset", "file_extension"=>"mp4", "key"=>"content_assets/1bd687a4-cb1e-487e-831f-ac607b99a0b3/original/Pg_24.mp4"}, {"guid"=>"7ade1e6b-f7a9-4016-9fcd-4134a6693700", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/7ade1e6b-f7a9-4016-9fcd-4134a6693700/encrypt/app_7ade1e6b-f7a9-4016-9fcd-4134a6693700.zip"}, {"guid"=>"8006b853-a01c-415e-9614-b3dc3c2428a5", "asset_type"=>"ContentAsset", "file_extension"=>"mp4", "key"=>"content_assets/8006b853-a01c-415e-9614-b3dc3c2428a5/original/ch7_pg97_Nervous_System-The_Reflex_Action.mp4"}, {"guid"=>"26462395-3475-4cea-ac6d-439196ac5e2b", "asset_type"=>"ContentAsset", "file_extension"=>"zip", "key"=>"content_assets/26462395-3475-4cea-ac6d-439196ac5e2b/encrypt/app_26462395-3475-4cea-ac6d-439196ac5e2b.zip"}]
    data.each do |d|
      begin
        guid = d['guid']
        guid_a = "0e6dcd16-38f9-4346-8685-a326ae641d24"
        guid_h = "0e7bdeca-c4e2-44e0-b580-db1d819b4660"
        folder_path = "/home/dilipbv/content_assets/#{guid}/original/"

        file_names = []
        file_types = []

        Dir[folder_path+"*"].each do |file|
          file_names << File.basename(file)
          file_types << (File.basename(file)).split('.').last
        end

        if file_types.include? 'zip'
          base_file = ''
          file_names.each do |n|
            base_file = n if n.split('.').last == 'zip'
          end

          Zip::File.open(folder_path+base_file) do |zip_file|
            zip_file.each do |entry|
              if entry.name == "assessment.json"
                type = 'assessment'
                name = (JSON.parse(entry.get_input_stream.read))['name']
              elsif entry.name.split('.').last == "m3u8"
                type = 'mp4'
                name = base_file.split('.').first
              elsif entry.name.split('.').last == "html"
                type = 'html5'
                name = base_file.split('.').first
              end
            end
          end

          file_path = folder_path + base_file

        elsif file_types.include? 'mp3'
          base_file = ''
          file_names.each do |n|
            base_file = n if n.split('.').last == 'mp3'
          end

          file_path = folder_path + base_file
          name = base_file.split('.').first
          type = 'mp3'
        elsif file_types.include? 'mp4'
          base_file = ''
          file_names.each do |n|
            base_file = n if n.split('.').last == 'mp4'
          end

          #file_path = folder_path + base_file
          file_path =
              name = base_file.split('.').first
          type = 'mp4'

        elsif file_types.include? 'pdf'
          base_file = ''
          file_names.each do |n|
            base_file = n if n.split('.').last == 'pdf'
          end

          file_path = folder_path + base_file
          name = base_file.split('.').first
          type = 'pdf'
        elsif file_types.include? 'json'
          base_file = ''
          file_names.each do |n|
            base_file = n if n.split('.').last == 'json'
          end

          file_path = folder_path + base_file
          name = base_file.split('.').first
          type = 'toc'
        end

        if File.exists? file_path
          content_server ||= ContentServer.new(guid: guid, type: type)
          success = content_server.upload_file(name,file_path, tags)

          r = {}
          r['guid'] = guid
          r['success'] = success

          result_data << r
        end
      rescue
        r = {}
        r['guid'] = guid
        r['success'] = success

        result_data << r
      end
    end
    puts "result_data is #{result_data}"
  end

end
