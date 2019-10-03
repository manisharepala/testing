class QuizSectionLanguageSpecificData
  include Mongoid::Document

  field :name, type: BSON::Binary
  field :description, type: BSON::Binary
  field :instructions, type: BSON::Binary

  field :language, type: String, default: 'english'

  embedded_in :quiz_section, :inverse_of => :quiz_section_language_specific_datas
  # validates_presence_of :question_text

  def as_json(with_key: false)
    if with_key
      super(except: [:_id, :created_at, :updated_at]).merge(name:name,description:description,instructions:instructions,language:language)
    else
      super(only: [:statement]).merge(id: self.id.to_s)
    end
  end
end
