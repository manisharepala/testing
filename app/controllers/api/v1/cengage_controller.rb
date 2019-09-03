class Api::V1::CengageController < ApplicationController

  def assessment_types
    data = ['JEE Mains', 'JEE Advanced']

    render json: data
  end

  def list_of_assessments
    data = []
    [1,2,3,4,5].each do |i|
      data << {'name'=>"#{params[:assessment_type]}-Test-#{i}",'guid'=>"guid-#{1}"}
    end

    render json: data
  end

  def subjects
    data = [{'name'=>'Maths','guid'=>'7f7fcb9f-903c-4f0a-9eaf-bf50b4a84020'},{'name'=>'Physics','guid'=>'7f7fcb9f-903c-4f0a-9eaf-bf50b4a82345'},{'name'=>'Chemistry','guid'=>'7f7fcb9f-wert-4f0a-9eaf-bf50b4a84020'}]

    render json: data
  end

end