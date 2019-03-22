class QuizSection
  include Mongoid::Document

  # field :name, type: String
  # field :instructions, type: BSON::Binary
  embeds_many :quiz_section_language_specific_datas, cascade_callbacks: true
  accepts_nested_attributes_for :quiz_section_language_specific_datas
  field :question_ids, type: Array

  field :parent_id, type: String
  field :child_ids, type: Array

  belongs_to :quiz
  # embedded_in :quiz
  #embeds_many :quiz_question_instances, as: :question_instances
  # has_many :questions, :through=>:quiz_question_instances

  # validates_presence_of :name

  def as_json(with_language_support: false)
    quiz_section_name_data = {}
    quiz_section_instructions_data = {}

    quiz_section_language_specific_datas.each do |d|
      quiz_section_name_data[d.language] = d.name
      quiz_section_instructions_data[d.language] = d.instructions
    end
    if with_language_support
      return {name:quiz_section_name_data, instructions:quiz_section_instructions_data, question_ids:question_ids, quiz_sub_sections:[]}
    else
      return {name:quiz_section_name_data['english'], instructions:quiz_section_instructions_data['english'], question_ids:question_ids, quiz_sub_sections:[]}
    end

  end


  def self.create_quiz_section(attrs)
    q = QuizSection.send(:new, attrs)
    q.save!
  end
end
