class TagsController < ApplicationController

  skip_before_action :authenticate_user!

  def get_child_tags
    data = TagsServer.get_child_tags(params[:guid])
    render json: data
  end

  def update_question_tags
    question = Question.find(params[:question_id])
    question.tag_ids = [params[:course_guid],params[:grade_guid],params[:subject_guid],params[:chapter_guid],params[:concept_guid],params[:difficulty_level_guid],params[:blooms_taxonomy_guid]]
    question.save!
    head :ok
  end

end