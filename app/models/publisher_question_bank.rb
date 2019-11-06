class PublisherQuestionBank
  include Mongoid::Document
  include Mongoid::Timestamps
  field :name, type: String
  field :description, type: String
  field :publisher_id, type: Integer

  # belongs_to :tags_db
  validates_presence_of :name, :description
  # has_and_belongs_to_many :questions

  # accepts_nested_attributes_for :questions

  def self.valid_ids?(ids, user_id)
    true
  end

  def self.get_tags_db_id(publisher_question_bank_id)
    if publisher_question_bank_id == "5c2c591368ce591e55ed0293"
      return '5c209b1e68ce596b0168bf33'
    elsif publisher_question_bank_id == "5d775e46fdbd262e669612cb"
      return '5d7623c6fdbd263418f59abc'
    elsif publisher_question_bank_id == "5dc2885cfdbd26388aa2e2a2"
      return '5dc2877cfdbd266534cd7873'
    else
      return '5c209b1e68ce596b0168bf33'
      # raise Exception.new('Institution and tags Db do not match')
    end
  end

  def self.get_institute_name(publisher_question_bank_id)
    if publisher_question_bank_id == "5c2c591368ce591e55ed0293"
      return 'learnflix'
    elsif publisher_question_bank_id == "5d775e46fdbd262e669612cb"
      return 'cengage'
    elsif publisher_question_bank_id == "5dc2885cfdbd26388aa2e2a2"
      return 'tata_classes'
    else
      return 'learnflix'
      # raise Exception.new('Institution and tags Db do not match')
    end
  end

end
