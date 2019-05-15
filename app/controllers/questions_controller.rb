class QuestionsController < ApplicationController
  skip_before_action :authenticate_user!     #, only: [:show, :index]
  before_action :set_question, only: [:show, :edit, :update]

  def show
    logger.info params
  end

  def edit
    @tags = {}
    @tags['course'] = [['CBSE','CBSE'],['SSC','SSC']]
    @tags['grade'] = [['CBSE','CBSE'],['SSC','SSC']]
    @tags['subject'] = [['CBSE','CBSE'],['SSC','SSC']]
    @tags['chapter'] = [['CBSE','CBSE'],['SSC','SSC']]
    @tags['concept'] = [['CBSE','CBSE'],['SSC','SSC']]
  end

  def update
    qlsd_params = question_params['question_language_specific_datas_attributes'].to_h
    data = {default_mark: question_params['default_mark'],question_language_specific_datas: [question_text: Question.get_original_text(qlsd_params.values[0]['question_text']),general_feedback: Question.get_original_text(qlsd_params.values[0]['general_feedback']),hint: Question.get_original_text(qlsd_params.values[0]['hint']),actual_answer: Question.get_original_text(qlsd_params.values[0]['actual_answer'])]}


    if params[:qtype] == 'SmcqQuestion' || params[:qtype] == 'MmcqQuestion' || params[:qtype] == 'TrueFalseQuestion' || params[:qtype] == 'McqMatrixQuestion' || params[:qtype] == 'AssertionReasonQuestion'
      qa_params = question_params['question_answers_attributes'].to_h
      qa_values = []
      qa_params.values.each do |h|
        d = {}
        d['answer_english'] = Question.get_original_text(h['answer_english'])
        d['id'] = h['id']
        d['fraction'] = h['fraction']
        qa_values << d
      end
      data = data.merge(question_answers_attributes:qa_values)
    elsif params[:qtype] == 'FibQuestion'
    end

    respond_to do |format|
      if @question.update_attributes(data)
        Question.process_new_images(@question.id)
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
      params.require(:smcq_question).permit(:default_mark,question_language_specific_datas_attributes: [:question_text,:general_feedback,:actual_answer,:hint], question_answers_attributes: [:answer_english,:answer_hindi, :id, :fraction])
    elsif params[:qtype] == 'TrueFalseQuestion'
      params.require(:true_false_question).permit(:default_mark,question_language_specific_datas_attributes: [:question_text,:general_feedback,:actual_answer,:hint], question_answers_attributes: [:answer_english,:answer_hindi, :id, :fraction])
    elsif params[:qtype] == 'MmcqQuestion'
      params.require(:mmcq_question).permit(:default_mark,question_language_specific_datas_attributes: [:question_text,:general_feedback,:actual_answer,:hint], question_answers_attributes: [:answer_english,:answer_hindi, :id, :fraction])
    elsif params[:qtype] == 'FibQuestion'
      params.require(:fib_question).permit(:default_mark,question_language_specific_datas_attributes: [:question_text,:general_feedback,:actual_answer,:hint])
    elsif params[:qtype] == 'SubjectiveQuestion'
      params.require(:subjective_question).permit(:default_mark,question_language_specific_datas_attributes: [:question_text,:general_feedback,:actual_answer,:hint])
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
