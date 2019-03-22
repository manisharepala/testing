class QuizTargetedGroup
  include Mongoid::Document
  # include Mongoid::Timestamps

  field :quiz_type, type: Integer
  field :password, type: String
  field :shuffle_questions, type: Boolean, default: false
  field :shuffle_options, type: Boolean, default: false
  field :pause, type: Boolean, default: false
  field :evaluate_server_side, type: Boolean, default: false
  field :key_update, type: Boolean, default: false
  field :time_open, type: Integer
  field :time_close, type: Integer
  field :show_score_after, type: Integer, default:0
  field :show_answers_after, type: Integer, default:0
  field :max_no_of_attempts, type: Integer, default:100

  field :published_by, type: Integer
  field :published_on, type: DateTime
  field :group_id, type: Integer
  field :user_id, type: Integer
  field :guid, type: String

  field :message_subject, type: String
  field :message_body, type: String

  field :quiz_id, type: String

  before_create :set_defaults

  def set_defaults
    self.published_on = Time.now.to_i
    self.guid = SecureRandom.uuid
  end

  def as_json
    data = {}
    data['id'] = id
    data['quiz_id'] = quiz_id
    data['password'] = password
    data['shuffle_questions'] = shuffle_questions
    data['shuffle_options'] = shuffle_options
    data['pause'] = pause
    data['time_open'] = time_open
    data['time_close'] = time_close
    data['show_score_after'] = show_score_after
    data['show_answers_after'] = show_answers_after
    data['message_subject'] = message_subject
    data['message_body'] = message_body
    data['max_no_of_attempts'] = max_no_of_attempts

    return data
  end

  def id
    self._id.to_s
  end
end
