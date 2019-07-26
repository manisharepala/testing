class TocData
  include Mongoid::Document
  include Mongoid::Timestamps
  store_in client: "content"

  field :guid, type: String
  field :name, type: String
  field :book_guid, type: String
  field :player, type: String
  field :params, type: Hash, default: {}
  field :metadata, type: Hash, default: {}
  field :downloadId, type: String
  field :src, type: String
  field :label, type: String
  field :parent_id, type: String
  field :path, type: String

  index({guid:1})
  index({book_guid:1,guid:1})

end