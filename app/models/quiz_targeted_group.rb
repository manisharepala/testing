class QuizTargetedGroup
  include Mongoid::Document
  # include Mongoid::Timestamps

  field :quiz_type, type: Integer
  field :password, type: String
  field :shuffle_questions, type: Boolean, default: false
  field :shuffle_options, type: Boolean, default: false
  field :pause, type: Boolean, default: false
  field :time_open, type: DateTime
  field :time_close, type: DateTime
  field :show_score_after, type: Integer
  field :show_answers_after, type: Integer

  field :published_by, type: Integer
  field :published_on, type: DateTime
  field :group_id, type: Integer
  field :guid, type: String

  field :message_subject, type: String
  field :message_body, type: String

  embedded_in :quiz

  before_create :set_defaults

  def set_defaults
    self.published_on = Time.now.to_i
    self.guid = SecureRandom.uuid
  end

  def self.create_quiz_targeted_group(attrs)
    q = QuizTargetedGroup.send(:new, attrs)
    q.save!
  end
end
