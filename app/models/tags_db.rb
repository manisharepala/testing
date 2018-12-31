class TagsDb
  include Mongoid::Document
  include Mongoid::Timestamps

  field :name, type: String
  field :user_ids, type: Array

  validates_presence_of  :name
  has_many :tags

end