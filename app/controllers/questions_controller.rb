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
    logger.info "2222222222222222222222222222222222222222222222222222222222222222222222222222222222222"
    logger.info qd_params.values[0]['question_text']
    # @question.question_language_specific_datas_attributes = qd_params.values
    # @question.save!

    logger.info "3333333333333333333333333333333333333333333333333333333333333333333333333333333"
    logger.info question_params['question_language_specific_datas_attributes'].values[0]['question_text']
    logger.info question_params[:qtype]
    logger.info "44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444"
    logger.info @question.question_language_specific_datas[0].question_text.html_safe
    ques_images = []
    images = []
    @question.question_language_specific_datas.each do |qlsd|
      Nokogiri::HTML(qlsd.question_text).css('img').map{ |i| i['src'] }.each do |img|
        ques_images << img.split("/").last
        images << img
      end

      Nokogiri::HTML(qlsd.general_feedback).css('img').map{ |i| i['src'] }.each do |img|
        images << img
        ques_images << img.split("/").last
      end
    end

    if @question.qtype == 'MmcqQuestion' || @question.qtype == 'SmcqQuestion' || @question.qtype == 'AssertionReasonQuestion' || @question.qtype == 'McqMatrixQuestion' || @question.qtype == 'TrueFalseQuestion'
      @question.question_answers.each do |qa|
        logger.info "---------------------------------------------------------------------qa---------------------------------------------------------------------------------------------------------"
        logger.info qa
        Nokogiri::HTML(qa.answer_english).css('img').map{ |i| i['src'] }.each do |img|
          images << img
          ques_images << img.split("/").last
        end
      end
    end

    if params[:qtype] == 'SmcqQuestion' || params[:qtype] == 'MmcqQuestion' || params[:qtype] == 'TrueFalseQuestion' || params[:qtype] == 'McqMatrixQuestion' || params[:qtype] == 'AssertionReasonQuestion'
      qa_params = question_params['question_answers_attributes'].to_h
      logger.info "------------------------------------------------------------------------qa_params-----------------------------------------------------------------------------------------------------"
      logger.info qa_params
      @question.question_answers_attributes = qa_params.values
      @question.save!
    elsif params[:qtype] == 'FibQuestion'
    end
     @question.update_attributes( default_mark: question_params['default_mark'],question_language_specific_datas: [question_text: qd_params.values[0]['question_text'],general_feedback: qd_params.values[0]['general_feedback']]) rescue 'question text and explanation'

     send_question_images(images,question_params)
     # if @question.update_attributes( default_mark: question_params['default_mark'],question_language_specific_datas: [question_text: qd_params.values[0]['question_text'],general_feedback: qd_params.values[0]['general_feedback']])
     #
     # end
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


  def send_question_images(images,question_params)
    src_images = []
    src_image_path = []
    que = question_params['question_language_specific_datas_attributes'].values[0]['question_text']
    gen = question_params['question_language_specific_datas_attributes'].values[0]['general_feedback']
    Nokogiri::HTML(que).css('img').map{ |i| i['src'] }.each do |img|
      src_images << img.split("/").last
      src_image_path << img
    end
    Nokogiri::HTML(gen).css('img').map{ |i| i['src'] }.each do |img|
      src_images << img.split("/").last
      src_image_path << img
    end

    if params[:qtype] == 'SmcqQuestion' || params[:qtype] == 'MmcqQuestion' || params[:qtype] == 'TrueFalseQuestion' || params[:qtype] == 'McqMatrixQuestion' || params[:qtype] == 'AssertionReasonQuestion'
      question_params['question_answers_attributes'].each do |qa|
        Nokogiri::HTML(qa[1]['answer_english']).css('img').map{ |i| i['src'] }.each do |img|
          src_images << img.split("/").last
          src_image_path << img
        end
      end
    end
    image_ids = []
    src_image_names = src_images.map{|n| n.downcase.split('.')[0]}
    dir_path = Rails.root.to_s + "/public"
    src_image_names.each do |src_image_name|
      index = src_image_names.index(File.basename(src_image_name).split('.')[0].downcase)
      img_name = (src_images[index]).split('.')[0] + ".jpg"
      file_image= (src_image_path[index]).split('?').first
      logger.info "---------------------------------------------------------------------file images----------------------------------------------------------------------------------------------------"
      logger.info images[index]
      if(images.count>0)
        image= (images[index]).split('/').last.split('.')[0]
      else
        image =[]
      end
      logger.info "---------------------------------------------------------------------images----------------------------------------------------------------------------------------------------"
      logger.info src_image_name
      logger.info image
      if(src_image_name !=image)
        logger.info "--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------"
        image_ids << (Image.create(name: img_name, key: file_image, file_path:(dir_path+file_image))).guid
        logger.info "---------------------------------------------------------------------image_ids----------------------------------------------------------------------------------------------------"
        logger.info image_ids
      end
    end
    @question.image_ids = image_ids
    @question.save!
    @question.upload_images
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
