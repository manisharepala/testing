class QuizSection
  include Mongoid::Document

  # field :name, type: String
  # field :instructions, type: BSON::Binary
  embeds_many :quiz_section_language_specific_datas, cascade_callbacks: true
  accepts_nested_attributes_for :quiz_section_language_specific_datas, :reject_if => :all_blank, :allow_destroy => true
  field :question_ids, type: Array

  field :parent_id, type: String
  field :child_ids, type: Array

  field :quiz_id, type: String
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
      return {id:_id.to_s,name:quiz_section_name_data, instructions:quiz_section_instructions_data, question_ids:question_ids.map{|id| id.to_s}, quiz_sub_sections:[]}
    else
      return {id:_id.to_s,name:quiz_section_name_data['english'], instructions:quiz_section_instructions_data['english'], question_ids:question_ids.map{|id| id.to_s}, quiz_sub_sections:[]}
    end
  end

  def name
    quiz_section_language_specific_datas.where(language:Language::ENGLISH)[0].name rescue 'quiz_section_name'
  end

  def self.create_quiz_section(attrs)
    q = QuizSection.send(:new, attrs)
    q.save!
  end
end
