class QuizSection
  include Mongoid::Document

  field :name, type: String
  field :instructions, type: BSON::Binary

  # field :parent_id, type: Integer
  # has_many :children_sections, class_name: "QuizSection", foreign_key: "parent_id"
  # belongs_to :parent_section, class_name: "QuizSection" , foreign_key: "parent_id"

  embedded_in :quiz
  # embedded_in :quiz
  embeds_many :quiz_question_instances, as: :question_instances
  # has_many :questions, :through=>:quiz_question_instances

  validates_presence_of :name, :instructions


  def self.create_quiz_section(attrs)
    q = QuizSection.send(:new, attrs)
    q.save!
  end
end
