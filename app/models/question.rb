class Question
  include Mongoid::Document
  include Mongoid::Timestamps
  field :question_text,as: :questiontext, type: BSON::Binary
  field :default_mark,as: :defaultmark, type: Float, default: 1
  field :penalty, type: Float, default: 0
  field :_type, as: :qtype, type: String
  field :active, type: Boolean, default: true
  field :generalfeedback,as: :general_feedback, type: BSON::Binary
  field :hint, type: BSON::Binary
  field :actual_answer, type: BSON::Binary
  field :created_by, type: Integer
  field :guid, type: String
  field :tag_ids, type: Array

  embeds_many :question_images, :cascade_callbacks => true
  # has_and_belongs_to_many :tags, index: true, autosave: true, inverse_of: nil # one side relation
  has_and_belongs_to_many :publisher_question_banks,index: true, autosave: true, inverse_of: nil # one side relation

  accepts_nested_attributes_for :publisher_question_banks

  # has_many :s3_files, as: :s3_asset, :dependent => :destroy

  # Validations
  validates_presence_of  :questiontext, :defaultmark, :penalty, :_type, :created_by
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

  def common_data_json(with_key: false, quiz_id: nil)
    # Marks and Penalty should be fetched from quiz
    data = {
        id: self.id.to_s,
        question_text: self.question_text,
        marks: self.default_mark,
        penalty: self.penalty,
        type: self.qtype
    }.merge(tags: tag_ids)
    # byebug
    if with_key
      data.merge!({
                      explaination: generalfeedback,
                      hint: hint
                  })
    end
    data
  end

  def add_tag(name,value)
    self.tag_ids << Question.get_tag_guid(name,value)
    self.save!
  end

  def remove_tag(name, value)
    guid = Question.get_tag_guid(name,value)
    if guid.present?
      self.update_attributes(tag_ids: (self.tag_ids - [guid]))
      return true
    end
    return false
  end

  def id
    self._id
  end


  def self.get_data_from_tags(method_name, body_data)
    uri = URI("http://13.233.76.145/#{method_name}")
    req = Net::HTTP::Get.new(uri.path, 'Content-Type' => 'application/json')
    req.body = body_data
    res = Net::HTTP.start(uri.hostname, uri.port) do |http|
      http.request(req)
    end
    return res.body
  end

  def self.get_tag_guid(name,value)
    require 'net/http'
    method_name = '/tags/find_tag'
    body_data = {name: name, value:value}.to_json

    res = Question.get_data_from_tags(method_name,body_data)
    if res.present?
      data = JSON.parse(res)
      return data['guid']
    else
      return nil
    end
  end

  protected

  def abstract_class
    errors.add(:qtype, 'Invalid qtype')
  end
end
