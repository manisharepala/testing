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
    publisher_question_bank_id = publisher_question_bank_id.to_s
    if publisher_question_bank_id == "5c2c591368ce591e55ed0293"
      return '5c209b1e68ce596b0168bf33'
    elsif publisher_question_bank_id == "5d775e46fdbd262e669612cb"
      return '5d7623c6fdbd263418f59abc'
    elsif publisher_question_bank_id == "5dc2885cfdbd26388aa2e2a2"
      return '5dc2877cfdbd266534cd7873'
      #####ignitor start
    elsif publisher_question_bank_id == "5ddd0a7414ba781e36352f80"
      return '5dd7af106a69c51de3a794c0'
    elsif publisher_question_bank_id == "5ddd0a7414ba781e36352f81"
      return '5dd7ae996a69c51de3a794be'
    elsif publisher_question_bank_id == "5ddd0a7414ba781e36352f82"
      return '5dd7aeb56a69c51de3a794bf'
    elsif publisher_question_bank_id == "5ddd0a7414ba781e36352f83"
      return '5dd26b7f6a69c512584b1ea5'
    else
      return '5c209b1e68ce596b0168bf33'
      # raise Exception.new('Institution and tags Db do not match')

      # Ignitor store data
      # [{"5ddd0a7414ba781e36352f80"=>"St-George"}, {"5ddd0a7414ba781e36352f81"=>"TCE"}, {"5ddd0a7414ba781e36352f82"=>"Gateforum"}, {"5ddd0a7414ba781e36352f83"=>"Edutor"}]
      # [["5dd26b7f6a69c512584b1ea5", "Sample-Db", "718c48e4-1919-4ae8-bdfe-9dc38e86553d"], ["5dd7ae996a69c51de3a794be", "TCE", "84f9b837-7313-4944-a376-49dd5ef2a7f3"], ["5dd7aeb56a69c51de3a794bf", "Gateforum", "7d613bcf-129d-4100-a042-d5948e2c0427"], ["5dd7af106a69c51de3a794c0", "St_George", "6f03a582-9895-49e7-a7d6-89cede413f29"]]
    end
  end

  def self.get_institute_name(publisher_question_bank_id)
    publisher_question_bank_id = publisher_question_bank_id.to_s
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
