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

  private_class_method :new, :create

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
        s3_image_download_url = Image.where(key:key).last.get_download_url
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

  def Question.process_text(text,s3_path,ques_id)
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

  protected

  def abstract_class
    errors.add(:qtype, 'Invalid qtype')
  end
end
