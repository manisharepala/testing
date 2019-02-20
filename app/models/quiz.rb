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
  field :player, type: String
  field :key, type: String
  field :file_path, type: String
  field :final, type: Boolean, default: false
  field :uploaded, type: Boolean, default: false
  field :focus_area, type: BSON::Binary
  field :time_open, type: DateTime
  field :time_close, type: DateTime
  field :quiz_json, type: BSON::Binary

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

    quiz.question_ids.each do |id|
      FileUtils.mkdir_p (quiz_zip_path+id)
      FileUtils.cp_r(Dir["#{question_images_path+id}/*"],quiz_zip_path+id)
    end

    File.open(quiz_zip_path+"assessment.json","w") do |f|
      f.write((quiz.as_json(with_key:true)).to_json)
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

  def as_json(with_key: false)
    des = '' if !description.present?
    ins = '' if !instructions.present?
    t_marks = '' if !total_marks.present?
    t_time = '' if !total_time.present?
    data = {name:name, description:des, instructions:ins, total_marks:t_marks, total_time:t_time, type:type, player:'', time_open:'', time_close:''} #,quiz_detail:quiz_detail.as_json

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

    data = [{"guid"=>"0e6dcd16-38f9-4346-8685-a326ae641d24", "asset_type"=>"ContentAsset", "file_extension"=>"mp4", "key"=>"content_assets/40be7d42-3b35-435a-b5e7-5b355721f97d/original/Pg_21.mp4"}]
    data.each do |d|
      guid = d['guid']
      guid_a = "0e6dcd16-38f9-4346-8685-a326ae641d24"
      guid_h = "0e7bdeca-c4e2-44e0-b580-db1d819b4660"
      folder_path = "/home/inayath/Desktop/s3_files/#{guid}/original/"

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
        success = content_server.update_file(name,file_path, tags)

        r = {}
        r['guid'] = guid
        r['success'] = success

        result_data << r
      end
    end
    puts "result_data is #{result_data}"
  end

end
