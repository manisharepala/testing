class Quiz
  include Mongoid::Document
  include Mongoid::Timestamps

  field :name, type: String
  field :description, type: String
  field :instructions, type: BSON::Binary
  field :total_marks, type: Float

  field :total_time, type: Integer # in minutes
  field :created_by, type: Integer
  field :tag_ids, type: Array
  field :question_ids, type: Array
  field :guid, type: String

  embeds_many :quiz_targeted_groups
  embeds_many :quiz_sections
  embeds_many :quiz_question_instances, as: :question_instances

  before_create :create_guid

  # has_and_belongs_to_many :tags, index: true, autosave: true, inverse_of: nil # one side relation
  # has_and_belongs_to_many :questions, index: true, autosave: true, inverse_of: nil # one side relation
  # has_many :questions
  # accepts_nested_attributes_for :questions, :quiz_sections, :quiz_targeted_groups

  # has_and_belongs_to_many :tags, index: true, autosave: true, inverse_of: nil # one side


  # field :created_by, type: Integer
  # field :institution_id, type: Integer
  # field :center_id, type: Integer

  def create_guid
    self.guid = SecureRandom.uuid
  end

  def self.create_quiz(attrs)
    # byebug
    q = Quiz.send(:new, attrs)
    q.save!
  end

  def as_json(with_key: false)
    data = {name:name, description:description, instructions:instructions, total_marks:total_marks, total_time:total_time} #,quiz_detail:quiz_detail.as_json

    if quiz_sections.count > 0
      quiz_sections_data = []
      quiz_sections.each do |qs|
        qqi_data = {name:qs.name, instructions:qs.instructions}
        questions_data = []
        qs.quiz_question_instances.each do |qqi|
          if with_key
            questions_data << qqi.question.as_json(with_key:with_key)
          else
            questions_data << qqi.question.as_json
          end
        end
        qqi_data = qqi_data.merge(questions:questions_data)
        quiz_sections_data << qqi_data
      end
      data = data.merge(quiz_sections:quiz_sections_data)
    else
      questions_data = []
      question_ids.each do |id|
        q = Question.find(id)
        if with_key
          questions_data << q.as_json(with_key:with_key)
        else
          questions_data << q.as_json
        end
      end
      data = data.merge(questions:questions_data)
    end

    return data
  end

end
