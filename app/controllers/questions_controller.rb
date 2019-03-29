class QuestionsController < ApplicationController
  skip_before_action :authenticate_user!     #, only: [:show, :index]
  before_action :set_question, only: [:show, :edit, :update]

  def show
    logger.info params
  end

  def edit
  end

  def update
    logger.info "11111111111111111111111111111111111111111"
    logger.info params
    logger.info "11111111111222222222222222222111111"
    logger.info question_params
    qd_params = question_params['question_language_specific_datas_attributes'].to_h
    # logger.info "2222222222222222222222222222222222222222222222222222222222222222222222222222222222222"
    # logger.info qd_params.values[0]['question_text']
    # @question.question_language_specific_datas_attributes = qd_params.values
    # @question.save!

    if params[:qtype] == 'SmcqQuestion' || params[:qtype] == 'MmcqQuestion' || params[:qtype] == 'TrueFalseQuestion' || params[:qtype] == 'McqMatrixQuestion' || params[:qtype] == 'AssertionReasonQuestion'
      qa_params = question_params['question_answers_attributes'].to_h
      # logger.info "33333333333333333333333333333333333333333333333333333333333"
      # logger.info qa_params
      @question.question_answers_attributes = qa_params.values
      @question.save!
    elsif params[:qtype] == 'FibQuestion'
    end
     @question.update_attributes( default_mark: question_params['default_mark'],question_language_specific_datas: [question_text: qd_params.values[0]['question_text'],general_feedback: qd_params.values[0]['general_feedback']]) rescue 'question text and explanation'

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
      params.require(:smcq_question).permit(:default_mark,question_language_specific_datas_attributes: [:question_text,:general_feedback], question_answers_attributes: [:answer_english,:answer_hindi, :id, :fraction])
    elsif params[:qtype] == 'TrueFalseQuestion'
      params.require(:true_false_question).permit(:default_mark,question_language_specific_datas_attributes: [:question_text,:general_feedback], question_answers_attributes: [:answer_english,:answer_hindi, :id, :fraction])
    elsif params[:qtype] == 'MmcqQuestion'
      params.require(:mmcq_question).permit(:default_mark,question_language_specific_datas_attributes: [:question_text,:general_feedback], question_answers_attributes: [:answer_english,:answer_hindi, :id, :fraction])
    elsif params[:qtype] == 'FibQuestion'
      params.require(:fib_question).permit(:default_mark,question_language_specific_datas_attributes: [:question_text,:general_feedback])
    elsif params[:qtype] == 'SubjectiveQuestion'
      params.require(:subjective_question).permit(:default_mark,question_language_specific_datas_attributes: [:question_text,:general_feedback])
    elsif params[:qtype] == 'PassageQuestion'
      params.require(:passage_question).permit(:default_mark,question_language_specific_datas_attributes: [:question_text,:general_feedback,:actual_answer,:hint])
    elsif params[:qtype] == 'McqMatrixQuestion'
      params.require(:mcq_matrix_question).permit(:default_mark,question_language_specific_datas_attributes: [:question_text,:general_feedback,:actual_answer,:hint])
    elsif params[:qtype] == 'AssertionReasonQuestion'
      params.require(:assertion_reason_question).permit(:default_mark,question_language_specific_datas_attributes: [:question_text,:general_feedback,:actual_answer,:hint])
    elsif params[:qtype] == 'FibIntegerQuestion'
      params.require(:fib_integer_question).permit(:default_mark,question_language_specific_datas_attributes: [:question_text,:general_feedback,:actual_answer,:hint], question_answers_attributes: [:answer_english,:answer_hindi, :id, :fraction])
    end
  end
end
