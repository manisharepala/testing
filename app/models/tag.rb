class Tag
  include Mongoid::Document
  include Mongoid::Timestamps
  field :name, type: String
  field :value, type: String

  belongs_to :tags_db
  validates_presence_of :name, :value
  validates :value, uniqueness: { scope: :name, message: "Same name, value pair can not be duplicated" }

  index name: 1
  def self.valid_ids?(ids, user_id)
    true
  end

  def as_json
    super(only: [:name, :value])
  end
end
