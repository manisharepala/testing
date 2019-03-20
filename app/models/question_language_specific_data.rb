class QuestionLanguageSpecificData
  include Mongoid::Document

  field :question_text, type: BSON::Binary
  field :general_feedback, type: BSON::Binary
  field :hint, type: BSON::Binary
  field :actual_answer, type: BSON::Binary

  field :language, type: String, default: 'english'

  embedded_in :question, :inverse_of => :question_language_specific_datas
  validates_presence_of :question_text

  def as_json(with_key: false)
    if with_key
      super(except: [:_id, :created_at, :updated_at]).merge(question_text:text,language:language)
    else
      super(only: [:statement]).merge(id: self.id.to_s)
    end
  end
end
