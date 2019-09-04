class Api::V1::CengageController < ApplicationController

  def assessment_types
    data = ['Concept','JEE Mains', 'JEE Advanced', 'BITS']

    render json: data
  end

  def list_of_assessments
    data = []
    [1,2,3,4,5].each do |i|
      data << {'name'=>"#{params[:assessment_type]}-Test-#{i}",'guid'=>"guid-#{i}"}
    end

    render json: data
  end

  def grade_subjects_chapters_concepts
    data = []

    [11,12].each do |grade|
      d = {}
      d['name'] = grade
      d['guid'] = SecureRandom.uuid
      d['subjects'] = []
      ['Mathematics','Physics','Chemistry'].each do |subject|
        d1 = {}
        d1['name'] = subject
        d1['guid'] = SecureRandom.uuid
        d1['total_questions_available'] = 1000
        d1['chapters'] = []
        [1,2,3,4,5].each do |chapter|
          d2 = {}
          d2['name'] = "#{subject}-chapter-#{chapter}"
          d2['guid'] = SecureRandom.uuid
          d2['total_questions_available'] = 200
          d2['topics'] = []
          [1,2,3].each do |topic|
            d3 = {}
            d3['name'] = "#{subject}-chapter-#{chapter}-topic-#{topic}"
            d3['guid'] = SecureRandom.uuid
            d3['total_questions_available'] = 67
            d2['topics'] << d3
          end
          d1['chapters'] << d2
        end
        d['subjects'] << d1
      end
      data << d
    end

    render json: data
  end

end