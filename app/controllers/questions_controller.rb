class QuestionsController < ApplicationController
  before_action :set_question, only: [:show, :edit, :update]

  def show

  end

  def edit
  end

  def update
    logger.info "11111111111111111111111111111111111111111"
    logger.info question_params

    if params[:qtype] == 'SmcqQuestion' || params[:qtype] == 'MmcqQuestion'
      qa_params = question_params['question_answers_attributes'].to_h
      @question.question_answers_attributes = qa_params.values
      @question.save!
    elsif params[:qtype] == 'FibQuestion'
    end

    @question.update_attributes(question_text: question_params['question_text'], general_feedback:question_params['general_feedback'])

    respond_to do |format|
      if true
        format.html { redirect_to assessment_question_show_path(id:@question.id), notice: 'Question was successfully updated.' }
      else
        format.html { render :edit }
      end
    end
  end

  def set_question
    @question = Question.find(params[:id])
  end

  private
  def question_params
    if params[:qtype] == 'SmcqQuestion'
      params.require(:smcq_question).permit(:question_text,:general_feedback, question_answers_attributes: [:answer, :id])
    elsif params[:qtype] == 'MmcqQuestion'
      params.require(:mmcq_question).permit(:question_text,:general_feedback, question_answers_attributes: [:answer, :id])
    elsif params[:qtype] == 'FibQuestion'
      params.require(:fib_question).permit(:question_text,:general_feedback)
    end
  end
end