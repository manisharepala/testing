class QuestionAnswer
  include Mongoid::Document
  field :answer_english, type: BSON::Binary
  field :answer_hindi, type: BSON::Binary
  field :feedback, type: BSON::Binary
  field :fraction, type: Boolean, default: false
  # field :language, type: String, default: 'English'
  embedded_in :objective_question, :inverse_of => :question_answers
  # validates_presence_of :answer_english

  def as_json(with_key: false,with_language_support:false)
    if with_key
      super(except: [:_id, :created_at, :updated_at, :answer_english, :answer_hindi]).merge(id: self.id.to_s)
    else
      super(only: [:answer]).merge(id: self.id.to_s)
    end
  end
end
