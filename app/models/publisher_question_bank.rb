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
end
