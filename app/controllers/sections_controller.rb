class SectionsController < ApplicationController
  skip_before_action :authenticate_user!     #, only: [:show, :index]
  before_action :set_section, only: [:section_show, :section_edit, :section_update]

  def new_section

  end

  def create

  end

  def get_quiz_sections
    quiz = Quiz.find(params[:id])
    @sections = QuizSection.where(:id.in=>quiz.quiz_section_ids)
  end

  def section_questions
    section = QuizSection.find(params[:id])
    @questions = Question.where(:id.in=>section.question_ids)
  end

  def section_show

  end

  def section_edit

  end

  def section_update
    s_params = section_params['quiz_section_language_specific_datas_attributes'].to_h
    logger.info s_params
    if @section.update_attributes(quiz_section_language_specific_datas: [name: s_params.values[0]['name']])
      redirect_to assessment_section_show_path(id:@section.id)
    else
      render 'edit'
    end
  end

  def set_section
    @section = QuizSection.find(params[:id])
  end

  private
  def section_params
    params.require(:quiz_section).permit(quiz_section_language_specific_datas_attributes: [:name])
  end

end
