class QuizAttemptData
  include Mongoid::Document
  include Mongoid::Timestamps
  field :data, type: BSON::Binary
  field :user_id, type: String

  index({:user_id=>1})
  index({'data.asset_download_id' => 1,:user_id=>1})
  index({'data.asset_download_id' => 1,:user_id=>1,'data.player_subtype'=>1})

end