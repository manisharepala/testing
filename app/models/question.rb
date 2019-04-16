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
      image = Image.where(:guid.in=>[guid])[0]
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
    tag_ids.each do |guid|
      d = TagsServer.get_tag_data(guid)
      tags_data << {d['name']=>d['value']} if d.present?
    end

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
      data.merge!(question_text:question_text_data.to_json)
    else
      data.merge!(question_text:question_text_data['english'].to_json)
    end
    # byebug
    if with_key
      if with_language_support
        data.merge!({
                        explanation: general_feedback_data.to_json,
                        hint: [hint_data.to_json]
                        #actual_answer:actual_answer_data.to_json
                    })
      else
        data.merge!({
                        explanation: general_feedback_data['english'].to_json,
                        hint: [hint_data['english'].to_json]
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
        replacement_paths << img.split("?").first
        logger.info "-------------------------------------------------------------------------------------replacement_paths----------------------------------------------------------------------------------"
        logger.info replacement_paths
      end
      replacement_paths.uniq.each do |rp|
        logger.info "---------------------------------------------------------------------------------------download_url-------------------------------------------------------------------------------------"
        logger.info rp
        logger.info "-------------------------------------------------------------------------key---------------------------------------------------------------------"
        logger.info (Image.where(:key.in=>[rp])[0]).get_download_url
        s3_image_download_url = (Image.where(:key.in=>[rp])[0]).get_download_url
        logger.info rp
        logger.info "---------------------------------------------------------------------------------------url_ text-------------------------------------------------------------------------------------"
        logger.info  s3_image_download_url
        logger.info rp
        logger.info (Image.where(:key.in=>[rp])[0]).get_download_url
        text = text.gsub(rp, s3_image_download_url)
        logger.info text
      end
    end
    return text
  end

  protected

  def abstract_class
    errors.add(:qtype, 'Invalid qtype')
  end
end
