class QuestionStatement
  include Mongoid::Document
  field :statement, type: BSON::Binary
  field :question_answer_ids, type: Array, default:[]
  embedded_in :matrix_question, :inverse_of => :question_statements
  validates_presence_of :statement

  def as_json(with_key: false,with_language_support:false)
    if with_key
      super(except: [:_id, :created_at, :updated_at,:question_answer_ids]).merge(id: self.id.to_s, match_option_ids:question_answer_ids)
    else
      super(only: [:statement]).merge(id: self.id.to_s)
    end
  end
end
