class QuestionsController < ApplicationController
  skip_before_action :authenticate_user!     #, only: [:show, :index]
  before_action :set_question, only: [:show, :edit, :update]

  def preview_section
    @section = params['section']
    render :template => 'questions/get_preview_section.js.erb', :locals => { @section => @section}
  end

  def import_questions
    @quiz = Quiz.find(params[:id])
    que = question_id_list_params['question_id'].split(",")
    logger.info "----------------------------------------------------------------------"
    logger.info @quiz.quiz_section_ids
    if @quiz.quiz_section_ids == []
      que.each do |q|
        @quiz.question_ids << q
        @quiz.save
      end
      total_marks = @quiz.question_ids.map{|id| Question.find(id).default_mark}.sum
      @quiz.total_marks = total_marks
    else
      quiz_section = QuizSection.find(question_id_list_params['sec_id'])
      que.each do |q|
        quiz_section.question_ids << q
        quiz_section.save
      end
      q_ids = @quiz.quiz_section_ids.map{|qs_id| QuizSection.find(qs_id).question_ids}.flatten
      total_marks = q_ids.map{|id| Question.find(id).default_mark}.sum
      @quiz.total_marks = total_marks
    end
    @quiz.save
    # redirect_to assessment_quiz_preview_assessment_path(quiz_id:@quiz.id)
  end

  def add_questions
    logger.info @quiz
    @quiz = Quiz.find(params[:id])
    if @quiz.quiz_section_ids.present?
      @quiz_sections = []
      @quiz.quiz_section_ids.each do |qs|
        @quiz_sections << QuizSection.find(qs)
      end
    end
    @question = Question.new
    @quiz_types = [['All Types', 'all_types'],['Concept Practice Objective' ,'concept_practice_objective'],['Concept Test Objective' ,'concept_test_objective'],['Concept Practice Subjective' ,'concept_practice_subjective'],['Concept Test Subjective' ,'concept_test_subjective'],['Challenge Test Objective' ,'challenge_test_objective'],['Challenge Test Subjective' ,'challenge_test_subjective'],['Chapter Practice Objective' ,'chapter_practice_objective'],['Chapter Test Objective' ,'chapter_test_objective'],['Chapter Practice Subjective' ,'chapter_practice_subjective'],['Chapter Test Subjective' ,'chapter_test_subjective'],['Challenge Test' ,'challenge test'], ['Subjective', 'subjective'], ['Try Out', 'tryout'], ['Concept Practice', 'concept_practice']]
    @tags = {}
    @tags['course'] = [TagsServer.get_tag_data(TagsServer.get_tag_guid('course','CBSE'))]
    @tags['difficulty_level'] = TagsServer.get_tags_by_name('difficulty_level')
    @tags['blooms_taxonomy'] = TagsServer.get_tags_by_name('blooms_taxonomy')
    @tags = @tags.merge(TagsServer.get_child_tags(@tags['course'][0]['guid']))
    @current_tags = {}
  end

  def get_questions_by_live_tags
    logger.info "--------------------------------------------------"
    logger.info params
    logger.info "---------------------------------------------------"
    @quiz= Quiz.find(params[:id])
    @tag_id = []
    @tag_id << questions_by_live_tags_params['course']
    @tag_id << questions_by_live_tags_params['grade'] if (!questions_by_live_tags_params['grade'].empty?)
    @tag_id << questions_by_live_tags_params['subject'] if (!questions_by_live_tags_params['subject'].empty?)
    @tag_id << questions_by_live_tags_params['chapter'] if (!questions_by_live_tags_params['chapter'].empty?)
    @tag_id << questions_by_live_tags_params['concept'] if (!questions_by_live_tags_params['concept'].empty?)
    q=PublisherQuestionBank.where(name:questions_by_live_tags_params['search_db'])
    qtype=questions_by_live_tags_params['qtype']
    if qtype.empty?
      # @que=Question.where(created_by:q[0].publisher_id,tag_ids: { '$all' => @tag_id }).order("timemodified desc")
      @que = Kaminari.paginate_array(Question.where(created_by:q[0].publisher_id,tag_ids: { '$all' => @tag_id }).order("timemodified desc")).page(params[:page]).per(10)
    else
      # @que=Question.where(created_by:q[0].publisher_id,qtype:qtype,tag_ids: { '$all' => @tag_id }).order("timemodified desc")
      @que = Kaminari.paginate_array(Question.where(created_by:q[0].publisher_id,qtype:qtype,tag_ids: { '$all' => @tag_id }).order("timemodified desc")).page(params[:page]).per(10)
    end
    respond_to do |format|
      format.html { ajax_refresh }
      format.js
    end
  end

  def ajax_refresh
    return render(:file => 'questions/get_questions_by_live_tags.js.erb')
  end

  def create_individual_question
    @quiz_types = [['All Types', 'all_types'],['Concept Practice Objective' ,'concept_practice_objective'],['Concept Test Objective' ,'concept_test_objective'],['Concept Practice Subjective' ,'concept_practice_subjective'],['Concept Test Subjective' ,'concept_test_subjective'],['Challenge Test Objective' ,'challenge_test_objective'],['Challenge Test Subjective' ,'challenge_test_subjective'],['Chapter Practice Objective' ,'chapter_practice_objective'],['Chapter Test Objective' ,'chapter_test_objective'],['Chapter Practice Subjective' ,'chapter_practice_subjective'],['Chapter Test Subjective' ,'chapter_test_subjective'],['Challenge Test' ,'challenge test'], ['Subjective', 'subjective'], ['Try Out', 'tryout'], ['Concept Practice', 'concept_practice']]
    @quiz= Quiz.find(params[:id])
    question_answer_params[:question_language_specific_datas_attributes].values.each do |item|
      Nokogiri::HTML(item[:question_text]).css('img').map{ |i| i['src'] }.each do |img|
        logger.info img.split("?").first
      end
    end

    if question_answer_params[:_type] == "selectoptiontype"
      render :template => 'questions/select_question.js.erb'
    else
      if (question_answer_params[:_type] == "MmcqQuestion" || question_answer_params[:_type] == "SmcqQuestion" || question_answer_params[:_type] == "TrueFalseQuestion" || question_answer_params[:_type] == "McqMatrixQuestion" || question_answer_params[:_type] == "AssertionReasonQuestion")
        @question = ObjectiveQuestion.create(question_answer_params)
      elsif (question_answer_params[:_type] == "TrueFalseQuestion" || question_answer_params[:_type] == "FibQuestion")
        @question = FibQuestion.create(question_answer_params)
      elsif (question_answer_params[:_type] == "PassageQuestion")
        @question = PassageQuestion.create(question_answer_params)
      end
      p=PublisherQuestionBank.where(name: question_answer_params['created_by'])
      publisher_question_bank_id = params[:publisher_question_bank_id]
      @question.created_by =p[0].publisher_id
      @question.tag_ids=[]
      @question.image_ids = []
      @question.tag_ids << params['tag']['course']
      @question.tag_ids << params['tag']['grade']
      @question.tag_ids << params['tag']['subject']
      @question.tag_ids << params['tag']['chapter']
      @question.tag_ids << params['tag']['concept']
      @question.tag_ids << params['tag']['difficulty_level']
      @question.tag_ids << params['tag']['blooms_taxonomy']
      @question.publisher_question_bank_ids << p[0].id
      question_answer_params[:question_language_specific_datas_attributes].values.each do |item|
        Nokogiri::HTML(item[:question_text]).css('img').map{ |i| i['src'] }.each do |img|
          key = img.split("?").first
          name = key.split("/").last
          file_path = "/home/krishna/work/assessment_app/public" + key
          @image = Image.create( key: key,name: name,file_path: file_path)
          @image.save
          @question.image_ids << @image.guid
        end
      end

      if @quiz.quiz_section_ids.present?
        @section = QuizSection.find(question_answer_params[:section_id])
      end

      unless @question.question_language_specific_datas.where(language: Language::ENGLISH)[0].question_text.blank?

        if valid_for_save(@question)
          @question.save(:validate => false)
          add_question_to_publisher_question_bank(publisher_question_bank_id,@question)
          if @quiz.quiz_section_ids.empty?
            questions =@quiz.question_ids
            questions << @question.id
            @quiz.question_ids = questions
          else
            @quiz.question_ids = []
            questions = @section.question_ids
            questions << @question.id
            @section.question_ids = questions
            @section.save
          end
          @quiz.save
          # redirect_to assessment_quiz_add_questions_path(id:@quiz.id)
        else
          @message = "Question cannot be saved because of inappropriate blank values"
          render :template => 'questions/action_failed.js.erb'
        end

      else
        @message = "Question text cannot be blank"
        render :template => 'questions/action_failed.js.erb'
      end
    end
    if @quiz.quiz_section_ids == []
      total_marks = @quiz.question_ids.map{|id| Question.find(id).default_mark}.sum
      @quiz.total_marks = total_marks
    else
      q_ids = @quiz.quiz_section_ids.map{|qs_id| QuizSection.find(qs_id).question_ids}.flatten
      total_marks = q_ids.map{|id| Question.find(id).default_mark}.sum
      @quiz.total_marks = total_marks
    end
    @quiz.save
  end

  def valid_for_save(question)
    return false if question.question_language_specific_datas.where(language: Language::ENGLISH)[0].question_text.blank?
    if (question.qtype=="multichoice" || question.qtype=="truefalse")
      if question.question_answers.empty?
        return false
      else
        question.question_answers.each {|question_answer|
          return true if question_answer.fraction==1
        }
        return false
      end
    elsif question.qtype=="fib"
      if question.question_fill_blanks.empty?
        return false
      else
        return true
      end
    else
      return true
    end
  end

  def add_question_to_publisher_question_bank(publisher_question_bank_id,question)
    unless publisher_question_bank_id.nil?
      PublisherQuestionBank.find(publisher_question_bank_id).questions << question
    end

  end
  def show
    logger.info params
  end

  def edit
    @tags = {}
    @tags['course'] = [TagsServer.get_tag_data(TagsServer.get_tag_guid('course','CBSE'))]
    @tags['difficulty_level'] = TagsServer.get_tags_by_name('difficulty_level')
    @tags['blooms_taxonomy'] = TagsServer.get_tags_by_name('blooms_taxonomy')
    @tags = @tags.merge(TagsServer.get_child_tags(@tags['course'][0]['guid']))

    @current_tags = {}
    (@question.tag_ids-[nil]).each do |guid|
      d = TagsServer.get_tag_data(guid)
      if d.present?
        @current_tags[d['name']] = [d['value'],d['guid']]
        @tags[d['name']] = (TagsServer.get_sibling_tags(d['guid']) - [nil]) if !(d['name'] == 'course' || d['name'] == 'difficulty_level' || d['name'] == 'blooms_taxonomy')
      end
    end
  end

  def update
    qlsd_params = question_params['question_language_specific_datas_attributes'].to_h
    data = {default_mark: question_params['default_mark'],question_language_specific_datas: [question_text: Question.get_original_text(qlsd_params.values[0]['question_text']),general_feedback: Question.get_original_text(qlsd_params.values[0]['general_feedback']),hint: Question.get_original_text(qlsd_params.values[0]['hint']),actual_answer: Question.get_original_text(qlsd_params.values[0]['actual_answer'])]}
    # @question.question_language_specific_datas_attributes = qd_params.values
    # @question.save!
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

  def question_answer_params
    params.require(:question).permit( :created_by,:section_id,:_type,:defaultmark,:penalty,question_language_specific_datas_attributes: [:question_text,:general_feedback,:hint, :actual_answer, :language], question_answers_attributes: [:answer_hindi, :answer_english, :fraction], question_fill_blanks: [{answer: []}, :case_sensitive])
  end

  def questions_by_live_tags_params
    params.require(:tag_list).permit(:search_db,:qtype,:course,:grade,:subject,:chapter,:concept,:difficulty_level,:blooms_taxonomy,:search_by_id)
  end

  def question_id_list_params
    params.require("question_id_list").permit(:question_id,:sec_id)
  end

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
