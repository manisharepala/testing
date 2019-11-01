class Question
  include Mongoid::Document
  include Mongoid::Timestamps

  embeds_many :question_language_specific_datas, cascade_callbacks: true

  field :default_mark,as: :defaultmark, type: Float, default: 1
  field :penalty, type: Float, default: 0
  field :partial_positive_marks, type: Float, default: 0
  field :partial_negative_marks, type: Float, default: 0

  field :_type, as: :qtype, type: String
  field :display_q_type, type: String
  field :active, type: Boolean, default: true
  field :created_by, type: Integer
  field :guid, type: String
  field :tag_ids, type: Array
  field :image_ids, type: Array
  field :section_id, type: String

  # embeds_many :images, :cascade_callbacks => true
  # has_and_belongs_to_many :tags, index: true, autosave: true, inverse_of: nil # one side relation
  has_and_belongs_to_many :publisher_question_banks,index: true, autosave: true, inverse_of: nil # one side relation

  accepts_nested_attributes_for :publisher_question_banks, :question_language_specific_datas

  # has_many :s3_files, as: :s3_asset, :dependent => :destroy

  # Validations
  validates_presence_of  :defaultmark, :penalty, :_type, :created_by
  validate :abstract_class
  validate do |record|
    # errors.add(:tag_ids, 'Must be a valid tag') unless Tag.valid_tags?(record.tag_ids, created_by)
    # errors.add(:question_bank_ids) unless PublisherQuestionBank.valid_ids?(record.question_bank_ids, created_by)
  end
  # validates :
  # Validations End
  index({ _type: 1 })
  index({"publisher_question_bank_ids" => 1, "_type" => 1})
  index({"tag_ids" => 1})

  default_scope ->{ where(active: true) }
  scope :with_tag, ->(tag_id, qb_id) {where(tag_ids: tag_id, publisher_question_bank_ids: qb_id)}
  scope :in_qb, ->(qb_id) {where(publisher_question_bank_ids: qb_id)}


  ABSTRACT_CLASSES = %w(Question SubjectiveQuestion ObjectiveQuestion)

  # private_class_method :new, :create

  def upload_images
    image_ids.each do |guid|
      image = Image.where(guid:guid)[0]
      image.upload_image
    end
  end

  def self.create_question(attrs)
    # byebug
    q = self.build_question(attrs)
    q.guid = SecureRandom.uuid
    q.save!
    return q
  end


  def self.build_question(args)
    if args.has_key?('qtype')
      sub_klass = args['qtype'].constantize
      args.delete 'qtype'
      return sub_klass.send(:new, args)
    else
      raise 'Invalid question type'
    end
  end

  def common_data_json(with_key: false, with_language_support: false)
    tags_data = []
    qtypes = { 'SmcqQuestion' => 'multichoice', 'SubjectiveQuestion' => 'subjective' }
    tag_ids.each do |guid|
      d = TagsServer.get_tag_data(guid)
      tags_data << {d['name']=>d['value']} if d.present?
    end
    tags_data <<  {"qsubtype"=>qtypes[_type]}

    question_text_data = {}
    hint_data = {}
    general_feedback_data = {}
    actual_answer_data = {}
    question_language_specific_datas.each do |d|
      question_text_data[d.language] = d.question_text
      hint_data[d.language] = d.hint
      general_feedback_data[d.language] = d.general_feedback
      actual_answer_data[d.language] = d.actual_answer
    end

    if 1==1
      question_type = self.qtype
    else
      question_type = self.display_q_type
    end

    data = {
        id: self.id.to_s,
        marks: self.default_mark,
        penalty: self.penalty,
        partial_positive_marks: self.partial_positive_marks,
        partial_negative_marks: self.partial_negative_marks,
        question_type: question_type,
        tags:tags_data
    }
    if with_language_support
      data.merge!(question_text:JSON.generate(question_text_data))
    else
      data.merge!(question_text:JSON.generate(question_text_data['english']))
    end
    # byebug
    if with_key
      if with_language_support
        data.merge!({
                        explanation: JSON.generate(general_feedback_data),
                        hint: JSON.generate(hint_data)
                        #actual_answer:actual_answer_data.to_json
                    })
      else
        data.merge!({
                        explanation: JSON.generate(general_feedback_data['english']),
                        hint: [JSON.generate(hint_data['english'])]
                        # actual_answer:actual_answer_data['english'].to_json
                    })
      end
    end
    return data
  end

  def add_tag(name,value)
    self.tag_ids << TagsServer.get_tag_guid(name,value)
    self.save!
  end

  def remove_tag(name, value)
    guid = TagsServer.get_tag_guid(name,value)
    if guid.present?
      self.update_attributes(tag_ids: (self.tag_ids - [guid]))
      return true
    end
    return false
  end

  def id
    self._id.to_s
  end

  def self.get_updated_text(text)
    if text.present?
      replacement_paths = []
      Nokogiri::HTML(text).css('img').map{ |i| i['src'] }.each do |img|
        replacement_paths << img
      end
      replacement_paths.uniq.each do |rp|
        if rp.include?('amazonaws.com')
          key = 'question_images' + rp.split('?')[0].split('question_images')[1]
        else
          key = rp
        end
        s3_image_download_url = Image.where(key:key).last.get_download_url rescue "http://13.234.165.191/icons/broken_image.jpg"
        text = text.gsub(rp, s3_image_download_url)
      end
    end
    return text
  end

  def self.get_original_text(text)
    if text.present?
      replacement_paths = []
      Nokogiri::HTML(text).css('img').map{ |i| i['src'] }.each do |img|
        replacement_paths << img
      end
      replacement_paths.uniq.each do |rp|
        if rp.include?('amazonaws.com')
          key = 'question_images' + rp.split('?')[0].split('question_images')[1]
          text = text.gsub(rp.gsub('&','&amp;'), key)
        end
      end
    end
    return text
  end

  def self.process_new_images(ques_id)
    s3_path = 'question_images/'
    question = Question.find(ques_id)
    question.question_language_specific_datas.each do |qlsd|
      qlsd.update_attributes(question_text:Question.process_text(qlsd.question_text,s3_path,ques_id), general_feedback:Question.process_text(qlsd.general_feedback,s3_path,ques_id),hint:Question.process_text(qlsd.hint,s3_path,ques_id),actual_answer:Question.process_text(qlsd.actual_answer,s3_path,ques_id))
    end
    if question.qtype == 'MmcqQuestion' || question.qtype == 'SmcqQuestion' || question.qtype == 'AssertionReasonQuestion' || question.qtype == 'McqMatrixQuestion' || question.qtype == 'TrueFalseQuestion'
      question.question_answers.each do |qa|
        qa.update_attributes(answer_english:Question.process_text(qa.answer_english,s3_path,ques_id))
      end
    end
  end

  def self.process_text(text,s3_path,ques_id)
    if text.present?
      # text = JSON.parse(text)
      image_names = []
      Nokogiri::HTML(text).css('img').map{ |i| i['src'] }.each do |img|
        image_names << img
      end

      image_names.uniq.each do |image_name|
        if !image_name.include? (ques_id)
          if image_name.include? ('question_images')
            img_base_name = image_name.split('/').last.split('?')[0]
            text = text.gsub(image_name, s3_path+ques_id+'/'+img_base_name)

            image = Magick::Image.read(Rails.root.to_s+"/public"+image_name.split('?')[0]).first

            FileUtils.mkdir_p(Rails.root.to_s+"/public/"+s3_path+ques_id) unless File.exists?(Rails.root.to_s+"/public/"+s3_path+ques_id)
            image.write(Rails.root.to_s+"/public/"+s3_path+ques_id+'/'+img_base_name)

            # creating Image reference for S3
            if_img = Image.where(key:"question_images/#{ques_id}/#{img_base_name}")[0]
            if !if_img.present?
              image1 = (Image.create(name: img_base_name, key: "question_images/#{ques_id}/#{img_base_name}", file_path:(Rails.root.to_s+"/public/"+s3_path+ques_id+'/'+img_base_name)))
              q = Question.find(ques_id)
              q.image_ids << image1.guid
              q.save!
              image1.upload_image
            end
          else

          end
        end
      end
    else
      text = ''
    end
    return text
  end

  #############################

  def self.verify_tags(test_paper,tags_db_id='5d7623c6fdbd263418f59abc')
    tag_not_present = []
    question_wise_tags_not_present = []

    (test_paper.xpath("group_questions") + test_paper.xpath("question_set")).each_with_index do |ques,i|
      tag_keys = Question.get_question_tag_keys(ques)

      if tag_keys.count == 5
        tag_keys.each do |key|
          if !TagsServer.get_tag_guid_by_key(key,tags_db_id).present?
            tag_not_present << key
          end
        end
      else
        tag_not_present = ["course", "grade", "subject", "chapter", "concept"] - tag_keys
      end

      if tag_keys.count != 5
        question_tag_not_present = {}
        question_tag_not_present['id'] = i+1
        question_tag_not_present['type'] = ques.xpath("qtype").attr("value").to_s rescue ''
        question_tag_not_present['tags_not_present'] = ["course", "grade", "subject", "chapter", "concept"] - tag_keys
        question_wise_tags_not_present << question_tag_not_present
      end
    end
    return [tag_not_present.uniq,question_wise_tags_not_present]
  end

  def self.get_question_tag_keys(ques)
    must_present_tag_names_for_each_question = ["course", "grade", "subject", "chapter", "concept"]
    five_compulsory_tags_data = {}
    ques.xpath("itags/itag").each do |tag|
      name = tag.attr("name").to_s
      value = tag.attr("value").to_s
      five_compulsory_tags_data[name] = value if must_present_tag_names_for_each_question.include? name
    end

    if five_compulsory_tags_data.keys.count == 5
      five_compulsory_tags_data_1 = {}
      five_compulsory_tags_data.keys.each_with_index do |k,i|
        five_compulsory_tags_data_1[must_present_tag_names_for_each_question[i]] = five_compulsory_tags_data[must_present_tag_names_for_each_question[i]]
      end
      key = ''
      five_compulsory_tags_data = {}
      five_compulsory_tags_data_1.keys.each_with_index do |k,i|
        if i!= 0
          key = key + '_' +five_compulsory_tags_data_1[k]
          five_compulsory_tags_data[k] = key
        else
          key = five_compulsory_tags_data_1[k]
          five_compulsory_tags_data[k] = key
        end
      end
      return five_compulsory_tags_data.values
    else
      return five_compulsory_tags_data.keys
    end
  end

  def self.create_simple_question(user_id, ques,publisher_question_bank_id, s3_path,master_dir,images_dir,institute_name,tags_db_id)
    question_data = Question.get_simple_question_hash(user_id,ques, publisher_question_bank_id,institute_name,tags_db_id)
    question = Question.create_question(question_data)
    Question.update_image_path(question._id,s3_path)
    Question.copy_question_images(question._id,master_dir,images_dir)
    return question
  end

  def self.update_image_path(ques_id,s3_path)
    question = Question.find(ques_id)
    question.question_language_specific_datas.each do |qlsd|
      qlsd.update_attributes(question_text:Question.update_img_src(qlsd.question_text,s3_path,ques_id), general_feedback:Question.update_img_src(qlsd.general_feedback,s3_path,ques_id),hint:Question.update_img_src(qlsd.hint,s3_path,ques_id),actual_answer:Question.update_img_src(qlsd.actual_answer,s3_path,ques_id))
    end
    if question.qtype == 'MmcqQuestion' || question.qtype == 'SmcqQuestion' || question.qtype == 'AssertionReasonQuestion' || question.qtype == 'McqMatrixQuestion' || question.qtype == 'TrueFalseQuestion'
      question.question_answers.each do |qa|
        qa.update_attributes(answer_english:Question.update_img_src(qa.answer_english,s3_path,ques_id))
      end
    end
  end

  def self.update_img_src(text,s3_path,ques_id)
    if text.present?
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

  def self.copy_question_images(ques_id,master_dir, images_dir)
    ques_images = []
    question = Question.find(ques_id)
    question.question_language_specific_datas.each do |qlsd|
      [qlsd.question_text,qlsd.general_feedback,qlsd.hint,qlsd.actual_answer].each do |text|
        Nokogiri::HTML(text).css('img').map{ |i| i['src'] }.each do |img|
          ques_images << img.split("/").last
        end
      end
    end

    if question.qtype == 'MmcqQuestion' || question.qtype == 'SmcqQuestion' || question.qtype == 'AssertionReasonQuestion' || question.qtype == 'McqMatrixQuestion' || question.qtype == 'TrueFalseQuestion'
      question.question_answers.each do |qa|
        Nokogiri::HTML(qa.answer_english).css('img').map{ |i| i['src'] }.each do |img|
          ques_images << img.split("/").last
        end
      end
    end

    ques_images = ques_images.uniq
    image_names = ques_images.map{|n| n.downcase.split('.')[0]}
    image_ids = []

    dir_path = Rails.root.to_s + "/public/question_images/#{ques_id}/"
    Dir["#{master_dir}/#{images_dir}/*"].each do |img|
      index = image_names.index(File.basename(img).split('.')[0].downcase)

      if index.present?
        FileUtils.mkdir_p(dir_path) unless File.exists?(dir_path)
        # copying to public folder
        img_name = (ques_images[index]).split('.')[0] + ".jpg"
        image = Magick::Image.read(img).first
        image.write(dir_path+img_name)

        # creating Image reference for S3
        if_img = Image.where(key:"question_images/#{ques_id}/#{img_name}")[0]
        image_ids << (Image.create(name: img_name, key: "question_images/#{ques_id}/#{img_name}", file_path:(dir_path+img_name))).guid if !if_img.present?
      end

    end
    question.image_ids = image_ids
    question.save!
    question.upload_images
  end

  def self.create_group_question(user_id, group_ques,publisher_question_bank_id,s3_path,master_dir,images_dir,institute_name,tags_db_id)
    question_data = Question.get_group_question_hash(user_id,group_ques, publisher_question_bank_id,s3_path,master_dir,images_dir,institute_name,tags_db_id)
    question = Question.create_question(question_data)
    Question.update_image_path(question._id,s3_path)
    Question.copy_question_images(question._id,master_dir,images_dir)
    return question
  end

  def self.get_group_question_hash(user_id, group_ques, publisher_question_bank_id,s3_path,master_dir,images_dir,institute_name,tags_db_id)
    data = {}
    data['publisher_question_bank_ids'] = [publisher_question_bank_id]
    data['question_language_specific_datas_attributes'] = []
    d = {}
    d['question_text'] = group_ques.xpath("instruction").inner_text rescue ''
    d['language'] = Language::ENGLISH

    data['question_language_specific_datas_attributes'] << d
    data['qtype'] = 'PassageQuestion'
    data['display_q_type'] = "Linked Comprehension Questions"
    data['created_by'] = user_id
    data['tag_ids'] = []

    tag_keys = get_question_tag_keys(group_ques)
    tag_keys.each do |key|
      data['tag_ids'] << TagsServer.get_tag_guid_by_key(key,tags_db_id)
    end

    group_ques.xpath("itags/itag").each do |tag|
      name = tag.attr("name").to_s
      value = tag.attr("value").to_s

      if ["difficulty_level", "blooms_taxonomy"].include? name
        data['tag_ids'] << TagsServer.get_tag_guid(name, value,tags_db_id)
      end
    end

    data['question_guids'] = []
    group_ques.xpath("question_set").each do |ques|
      child_question = Question.create_simple_question(user_id, ques,publisher_question_bank_id, s3_path,master_dir,images_dir,institute_name,tags_db_id)
      data['question_guids'] << child_question.guid
    end
    data['default_mark'] = data['question_guids'].map{|guid| Question.where(guid:guid)[0].default_mark}.sum
    return data
  end

  def self.get_simple_question_hash(user_id, ques, publisher_question_bank_id,institute_name,tags_db_id)
    data = {}
    data['publisher_question_bank_ids'] = [publisher_question_bank_id]

    data['question_language_specific_datas_attributes'] = []
    d = {}
    d['question_text'] = ques.xpath("question/question_text").inner_text
    d['general_feedback'] = ques.xpath("question/solution")[0].inner_text rescue ''
    d['actual_answer'] = ques.xpath("question/actual_answer").inner_text rescue ''
    d['hint'] = ques.xpath("question/hint").inner_text rescue ''
    d['language'] = Language::ENGLISH

    data['question_language_specific_datas_attributes'] << d

    data['qtype'] = Question.get_qtype(ques.xpath("qtype").attr("value").to_s.downcase,institute_name)
    data['display_q_type'] = Question.get_display_qtype(ques.xpath("qtype").attr("value").to_s.downcase,institute_name)
    data['default_mark'] = ques.xpath("score").attr("value").to_s.to_i rescue 1
    data['penalty'] = ques.xpath("penalty").attr("value").to_s.to_i rescue 0

    data['created_by'] = user_id

    if ['SmcqQuestion', 'MmcqQuestion', 'TrueFalseQuestion', 'McqMatrixQuestion', 'AssertionReasonQuestion'].include? data['qtype']
      data['question_answers_attributes'] = []
      fraction = ques.xpath("question/answer").attr("value").to_s.split(",") if !ques.xpath("question/answer").nil?
      ques.xpath("question/option").each_with_index do |option, index|
        data['question_answers_attributes'] << Question.get_question_answer_hash(fraction, index, option)
      end
    elsif ['FibQuestion', 'FibIntegerQuestion'].include? data['qtype']
      data['question_fill_blanks_attributes'] = []
      ques.xpath("question/options_fib").each do |option|
        data['question_fill_blanks_attributes'] << Question.get_question_fill_blank_hash(option)
      end
    end

    data['tag_ids'] = []

    tag_keys = get_question_tag_keys(ques)
    tag_keys.each do |key|
      data['tag_ids'] << TagsServer.get_tag_guid_by_key(key,tags_db_id)
    end

    ques.xpath("itags/itag").each do |tag|
      name = tag.attr("name").to_s
      value = tag.attr("value").to_s

      if ["difficulty_level", "blooms_taxonomy"].include? name
        data['tag_ids'] << TagsServer.get_tag_guid(name, value,tags_db_id)
      end
    end
    return data
  end

  def self.get_question_answer_hash(fraction, index, option)
    data1 = {}
    is_correct_option = 0
    if fraction.length == 1
      is_correct_option = Question.option_is_correct?(index, fraction.first) ? 1 : 0
    else
      if fraction.include?(%w(A B C D E)[index]) or fraction.include?(%w(1 2 3 4 5)[index])
        is_correct_option = 1
      else
        is_correct_option = 0
      end
    end
    data1['answer_english'] = option.xpath("option_text").inner_text
    data1['fraction'] = is_correct_option
    data1['feedback'] = option.xpath("feedback").inner_text
    return data1
  end

  def self.option_is_correct?(index,fraction)
    case index+1
      when 1 then true if (fraction == "A" or fraction == "1")
      when 2 then true if (fraction == "B" or fraction == "2")
      when 3 then true if (fraction == "C" or fraction == "3")
      when 4 then true if (fraction == "D" or fraction == "4")
      when 5 then true if (fraction == "E" or fraction == "5")
      else
        false
    end
  end

  def self.get_question_fill_blank_hash(option)
    data = {}
    data['answer'] = []
    option.xpath("option_blank").each do |option_blank|
      data['answer'] << option_blank.inner_text
    end
    data['case_sensitive'] = option.attr("value").to_s.to_i
    return data
  end

  def self.get_qtype(qtype,institute_name)
    if institute_name == 'cengage'
      if qtype == "Single Answer Type Questions".downcase
        "SmcqQuestion"
      elsif qtype == "Multiple Answers Type Questions".downcase
        "MmcqQuestion"
      elsif qtype == "Linked Comprehension Questions".downcase
        "PassageQuestion"
      elsif qtype == "Numerical Value Type Questions".downcase
        "FibIntegerQuestion"
      elsif qtype == "Matching Column Questions".downcase
        "McqMatrixQuestion"
      end
    elsif institute_name == 'learnflix'
      if qtype == "smcq"
        "SmcqQuestion"
      elsif qtype == "mmcq"
        "MmcqQuestion"
      elsif qtype == "fib"
        "FibQuestion"
      elsif qtype == "tof" || qtype == "truefalse"
        "TrueFalseQuestion"
      elsif qtype == "fibinteger"
        "FibIntegerQuestion"
      elsif qtype == "mcqmatrix"
        "McqMatrixQuestion"
      elsif qtype == "assertionreason"
        "AssertionReasonQuestion"
      elsif qtype == "saq" || qtype == "laq" || qtype == "vsaq"
        "SubjectiveQuestion"
      end
    end
  end

  def self.get_display_qtype(qtype,institute_name)
    if institute_name == 'cengage'
      if qtype == "Single Answer Type Questions".downcase
        "Single Answer Type Questions"
      elsif qtype == "Multiple Answers Type Questions".downcase
        "Multiple Answers Type Questions"
      elsif qtype == "Linked Comprehension Questions".downcase
        "Linked Comprehension Questions"
      elsif qtype == "Numerical Value Type Questions".downcase
        "Numerical Value Type Questions"
      elsif qtype == "Matching Column Questions".downcase
        "Matching Column Questions"
      end
    elsif institute_name == 'learnflix'
      if qtype == "smcq"
        "SmcqQuestion"
      elsif qtype == "mmcq"
        "MmcqQuestion"
      elsif qtype == "fib"
        "FibQuestion"
      elsif qtype == "tof" || qtype == "truefalse"
        "TrueFalseQuestion"
      elsif qtype == "fibinteger"
        "FibIntegerQuestion"
      elsif qtype == "mcqmatrix"
        "McqMatrixQuestion"
      elsif qtype == "assertionreason"
        "AssertionReasonQuestion"
      elsif qtype == "saq" || qtype == "laq" || qtype == "vsaq"
        "SubjectiveQuestion"
      end
    end
  end

  protected

  def abstract_class
    errors.add(:qtype, 'Invalid qtype')
  end
end
