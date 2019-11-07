class QuizzesController < ApplicationController

  skip_before_action :authenticate_user!, except:[:challenge_test_attempt_data, :get_all_quiz_attempt_datas, :get_quiz_attempt_data_by_id,:get_all_assessment_attempts,:get_user_attempt_analytics,:get_user_attempt_analytics_v1,:get_user_quiz_attempt_topic_details,:get_quiz_question_attempts,:get_given_quiz_analytics,:get_given_quiz_topic_analytics,:get_group_assessment_analytics, :get_group_assessment_rank_data, :get_group_assessment_subject_details, :get_assessment_group_topic_details,:get_question_error_analytics]

  def get_quizzes_analytics_data
    assessment_ids = params[:assessment_ids]
    concept_guids = params[:concept_ids]
    # Usage.where(:user_id=>48,"data.player"=>{:$in=>["TRYOUT", "OBJECTIVE ASSESSMENT", "SUBJECTIVE ASSESSMENT"]}).count

    d = {}
    correct_ids = []
    in_correct_ids = []
    skipped_ids = []
    un_attempted_ids = []

    assessment_ids.each do |guid|
      quiz = Quiz.where(guid:guid)[0]
      qad = QuizAttemptData.where("data.asset_download_id"=>guid,user_id:params[:user_id]).last

      if quiz.present? && quiz.focus_area.present?
        (JSON.parse(quiz.focus_area)).each do |fa|
          d[fa['guid']] ||= {}
          d[fa['guid']]['name'] = fa['name']
          d[fa['guid']]['total_questions'] ||= []
          d[fa['guid']]['total_questions'] << fa['questionIds'].uniq.map!{|e| e.to_s}
        end
      end

      if qad.present?
        correct_ids << qad.data['correct'].map{|id| id.to_s}
        in_correct_ids << qad.data['incorrect'].map{|id| id.to_s}
        skipped_ids << qad.data['skipped_questions'].map{|id| id.to_s}
        skipped_ids << qad.data['unattempted'].map{|id| id.to_s} #logic changed here (skipped + un_attempted)
      end
    end

    data = []
    d.keys.each do |guid|
      total_question_ids = d[guid]['total_questions'].flatten.uniq
      total_count = total_question_ids.count
      correct_count = (total_count - (total_question_ids - correct_ids.flatten.uniq).count)
      in_correct_count = (total_count - (total_question_ids - in_correct_ids.flatten.uniq).count)
      skipped_count = (total_count - (total_question_ids - skipped_ids.flatten.uniq).count)
      # un_attempted_count = (total_question_ids.count - (total_question_ids - un_attempted_ids.flatten.uniq).count)
      un_attempted_count = (total_count - (correct_count+in_correct_count+skipped_count))

      cd = {}
      cd['name'] = d[guid]['name']
      cd['guid'] = guid
      cd['correct_questions'] = ((correct_count/total_count.to_f)*100).round(1)
      cd['incorrect_questions'] = ((in_correct_count/total_count.to_f)*100).round(1)
      cd['skipped_questions'] = ((skipped_count/total_count.to_f)*100).round(1)
      cd['unattempted_questions'] = ((un_attempted_count/total_count.to_f)*100).round(1)

      data << cd if ((concept_guids.include? guid) && (total_count > 0))
    end

    render json: data
  end

  def challenge_test_attempt_data
    sort_stage = {
        "$sort" => { "created_at" => 1 }
    }

    match_stage = {
        "$match" => {
            "$and"=> [{ "data.book_id" => params[:book_guid]},
                      {"user_id" => current_user.id.to_s},
                      {"data.player_subtype" => "challenge test"}
            ]
        }
    }

    group_stage = {
        "$group" => {
            "_id" => {
                "asset_guid" => "$data.asset_guid"
            },
            "data"=>{ "$last"=> "$data"}
        }
    }
    disk_stage = {
        "allow_disk_use"=> true
    }

    project_stage = {
        "$project" => { "data"=> 1}
    }

    result = QuizAttemptData.collection.aggregate([sort_stage,match_stage,project_stage,group_stage],disk_stage)
    data = result.map{|d| {d['_id']['asset_guid']=>d['data']}}.reduce(:merge)

    render json: data
  end

  def get_are_assessments_attempted
    data = {}
    params[:assessment_ids].each do |assessment_id|
      data[assessment_id] = QuizAttemptData.where("data.asset_guid"=>assessment_id,user_id:params[:user_id])[0].present? ? true : false
    end

    render json: data
  end

  def get_book_assessments_attempted
    data = QuizAttemptData.where("data.book_id"=>params[:book_id],:user_id=>params[:user_id]).distinct("data.asset_guid")
    render json: data
  end

  def get_assessments_attempted_count
    data = {}
    assessment_ids = params[:assessment_ids]
    uniq_count = QuizAttemptData.where("data.asset_download_id"=>{:$in=>assessment_ids},user_id:params[:user_id]).group_by{|i| i.data["asset_download_id"]}.count

    data['attempted'] = uniq_count
    data['un_attempted'] = assessment_ids.count - uniq_count
    data['total'] = assessment_ids.count
    render json: data
  end

  def get_assessments_active_duration
    data = {}
    assessment_ids = params[:assessment_ids]
    duration_sum = QuizAttemptData.where("data.asset_download_id"=>{:$in=>assessment_ids},user_id:params[:user_id],"data.player_subtype"=>{ :$ne=> "tryout" }).sum("data.active_duration")#.map{|qad| qad.data['active_duration'].to_i}.sum rescue 0

    data['duration'] = duration_sum
    render json: data
  end

  def get_chapter_level_quizzes_analytics_data
    assessment_ids = params[:assessment_ids]

    correct_ids = []
    in_correct_ids = []
    skipped_ids = []
    un_attempted_ids = []

    assessment_ids.each do |guid|
      qad = QuizAttemptData.where("data.asset_download_id"=>guid,user_id:params[:user_id]).last

      if qad.present?
        correct_ids << qad.data['correct']
        in_correct_ids << qad.data['incorrect']
        skipped_ids << qad.data['skipped_questions']
        un_attempted_ids << qad.data['unattempted']
      end
    end

    correct_ids = correct_ids.flatten.uniq
    in_correct_ids = in_correct_ids.flatten.uniq
    skipped_ids = skipped_ids.flatten.uniq
    un_attempted_ids = un_attempted_ids.flatten.uniq

    total_question_ids = (correct_ids+in_correct_ids+skipped_ids+un_attempted_ids).flatten.uniq
    total_count = total_question_ids.count

    data = {}
    data['guid'] = params[:chapter_id]
    data['name'] = params[:chapter_name]
    data['correct_questions'] = ((correct_ids.count/total_count.to_f)*100).round(1)
    data['incorrect_questions'] = ((in_correct_ids.count/total_count.to_f)*100).round(1)
    data['skipped_questions'] = ((skipped_ids.count/total_count.to_f)*100).round(1)
    data['unattempted_questions'] = ((un_attempted_ids.count/total_count.to_f)*100).round(1)

    render json: data
  end

  def get_concept_wise_quizzes_analytics_data
    concept_wise_assessment_guids = params[:concept_wise_assessment_guids]
    data = []
    begin
      concept_wise_assessment_guids.each do |k,v|
        correct_ids = []
        in_correct_ids = []
        skipped_ids = []
        un_attempted_ids = []

        v['assessment_ids'].each do |guid|
          qad = QuizAttemptData.where("data.asset_download_id"=>guid,user_id:params[:user_id]).last

          if qad.present?
            correct_ids << qad.data['correct']
            in_correct_ids << qad.data['incorrect']
            skipped_ids << qad.data['skipped_questions']
            un_attempted_ids << qad.data['unattempted']
          end
        end

        correct_ids = correct_ids.flatten.uniq
        in_correct_ids = in_correct_ids.flatten.uniq
        skipped_ids = skipped_ids.flatten.uniq
        un_attempted_ids = un_attempted_ids.flatten.uniq

        total_question_ids = (correct_ids+in_correct_ids+skipped_ids+un_attempted_ids).flatten.uniq
        total_count = total_question_ids.count

        d = {}
        d['guid'] = k
        d['name'] = v['concept_name']
        d['correct_questions'] = ((correct_ids.count/total_count.to_f)*100).round(1)
        d['incorrect_questions'] = ((in_correct_ids.count/total_count.to_f)*100).round(1)
        d['skipped_questions'] = ((skipped_ids.count/total_count.to_f)*100).round(1)
        d['unattempted_questions'] = ((un_attempted_ids.count/total_count.to_f)*100).round(1)

        data << d
      end
    rescue
      data = []
    end

    render json: data
  end

  def get_quiz_attempt_data
    data = {}
    qad = QuizAttemptData.where("data.asset_download_id"=>params[:guid],user_id:params[:user_id].to_s).last
    if qad.present?
      data = qad.data
    end

    render json: data
  end

  def get_all_quiz_attempt_datas
    data = []
    qads = QuizAttemptData.where("data.asset_download_id"=>params[:guid],user_id:current_user.id)
    if qads.present?
      qads.each do |qad|
        data << qad.data.merge(id:qad.id.to_s)
      end
    end

    render json: data
  end

  def get_quiz_attempt_data_by_id
    data = {}
    qad = QuizAttemptData.find(params[:id])
    if qad.present?
      data = qad.data
    end

    render json: data
  end

  def get_assessments_attempt_data
    data = {}
    params[:assessment_ids].each do |assessment_id|
      data[assessment_id] = (QuizAttemptData.where("data.asset_download_id"=>assessment_id,user_id:params[:user_id].to_s).last.data rescue {})
    end

    render json: data
  end

  def get_multi_chapter_quiz_attempt_data
    data = {}
    qad = QuizAttemptData.where("data.asset_download_id"=>params[:guid],user_id:params[:user_id].to_s).last
    if qad.present?
      data = qad.data
    end

    render json: data
  end


  def quiz_edit
    @quiz = Quiz.find(params[:id])
  end

  def quiz_update
    @quiz = Quiz.find(params[:id])
    q_params = quiz_params['quiz_language_specific_datas_attributes'].to_h

    if @quiz.tags_verified
      if @quiz.update_attributes(quiz_language_specific_datas: [name: q_params.values[0]['name']], final: quiz_params[:final])
        redirect_to assessment_all_quizzes_path, notice:'Successful'
      else
        redirect_to assessment_quiz_edit_path(id:@quiz.id), notice:'Something went wrong'
      end
    else
      if quiz_params[:final] == '1'
        if Quiz.are_all_compulsory_tags_present(params[:id])
          if @quiz.update_attributes(quiz_language_specific_datas: [name: q_params.values[0]['name']], final: quiz_params[:final], tags_verified:true)
            redirect_to assessment_all_quizzes_path, notice:'Successful'
          else
            redirect_to assessment_quiz_edit_path(id:@quiz.id), notice:'Something went wrong'
          end
        else
          redirect_to assessment_quiz_edit_path(id:@quiz.id), notice:'Update Failed -> Not all questions have proper tags'
        end
      else
        if @quiz.update_attributes(quiz_language_specific_datas: [name: q_params.values[0]['name']], final: quiz_params[:final])
          redirect_to assessment_all_quizzes_path, notice:'Successful'
        else
          redirect_to assessment_quiz_edit_path(id:@quiz.id), notice:'Something went wrong'
        end
      end
    end
    @quiz.perform_later
  end

  def quiz_delete
    Quiz.find(params[:id]).destroy
    redirect_to assessment_all_quizzes_path
  end

  def get_focus_area
    data = Rails.cache.fetch("focus_area_#{params[:guid]}", expires_in: 7.days) do
      d = {}
      quiz = Quiz.where(guid: params[:guid])[0]
      if quiz.present? && quiz.focus_area.present?
        d = quiz.focus_area
      end
      d
    end
    render json: data
  end

  def update_focus_area
    quiz = Quiz.where(guid:params[:guid])[0]
    if !quiz.present?
      quiz = Quiz.create(quiz_language_specific_datas_attributes: [{name:'Quiz', language: 'english'}])
      quiz.guid = params[:guid]
      quiz.save!
    end
    quiz.update_attributes(focus_area: params[:focus_area])
    response = {}
    response['guid'] = quiz.guid
    if quiz.present?
      response['status'] = true
    else
      response['status'] = false
    end
    render json: response
  end

  def home

  end
  def preview_assessment
    logger.info "-------------------------------------------------------------------------preview assessment---------------------------------------------------------------------------"
    logger.info params
    @quiz = Quiz.find(params[:quiz_id])
    @quiz_types = [['All Types', 'all_types'],['Concept Practice Objective' ,'concept_practice_objective'],['Concept Test Objective' ,'concept_test_objective'],['Concept Practice Subjective' ,'concept_practice_subjective'],['Concept Test Subjective' ,'concept_test_subjective'],['Challenge Test Objective' ,'challenge_test_objective'],['Challenge Test Subjective' ,'challenge_test_subjective'],['Chapter Practice Objective' ,'chapter_practice_objective'],['Chapter Test Objective' ,'chapter_test_objective'],['Chapter Practice Subjective' ,'chapter_practice_subjective'],['Chapter Test Subjective' ,'chapter_test_subjective'],['Challenge Test' ,'challenge test'], ['Subjective', 'subjective'], ['Try Out', 'tryout'], ['Concept Practice', 'concept_practice']]
  end

  def new
    @quiz = Quiz.new
    @quiz_types = [['All Types', 'all_types'],['Concept Practice Objective' ,'concept_practice_objective'],['Concept Test Objective' ,'concept_test_objective'],['Concept Practice Subjective' ,'concept_practice_subjective'],['Concept Test Subjective' ,'concept_test_subjective'],['Challenge Test Objective' ,'challenge_test_objective'],['Challenge Test Subjective' ,'challenge_test_subjective'],['Chapter Practice Objective' ,'chapter_practice_objective'],['Chapter Test Objective' ,'chapter_test_objective'],['Chapter Practice Subjective' ,'chapter_practice_subjective'],['Chapter Test Subjective' ,'chapter_test_subjective'],['Challenge Test' ,'challenge test'], ['Subjective', 'subjective'], ['Try Out', 'tryout'], ['Concept Practice', 'concept_practice']]
  end

  def create
    @quiz = Quiz.new(quiz_params)
    if params['quiz_section_ids'] == "yes"
      quiz_section_params['quiz_section_language_specific_datas_attributes'].each do |qa|
        @quiz_section = QuizSection.create(quiz_section_language_specific_datas_attributes:[{name:qa[1]['name'],instructions:qa[1]['instructions']}])
        @quiz.quiz_section_ids << @quiz_section.id
        @quiz_section.quiz_id = @quiz.id
        @quiz_section.question_ids=[]
        @quiz_section.save
      end
    end
    if @quiz.save
      if params['quiz_section_ids'] == "yes"
        @quiz_section.save
      end
      redirect_to assessment_quiz_add_questions_path(id:@quiz.id)
    else
      render 'new'
    end
  end
  def publish_to
    logger.info "-------------------------------------"
    logger.info params
    @quiz = Quiz.find(params[:id])
    @target = QuizTargetedGroup.new
  end

  def publish
    logger.info "----------------------------------"
    logger.info params
    logger.info "000000000000000000000000000000000"
    @target = QuizTargetedGroup.create(publish_params)
    redirect_to assessment_all_quizzes_path
  end

  def show

  end

  def all_quizzes
    quizzes = Quiz.all.select{|q| (q.question_ids.count > 0 || q.quiz_section_ids.count > 0)}
    # @qb_map = PublisherQuestionBank.all.map{|d| {d.id => d.name}}.reduce(:merge)
    if params[:search]
      @item = params[:search]["item"]
      logger.info @item
      case params[:radios]
        when 'name'
          quiz = []
          quizzes.each do |q|
            if (q.quiz_language_specific_datas[0]['name'].downcase == @item.downcase rescue false)
              quiz << q
            end
          end
          @quiz = Kaminari.paginate_array(quiz).page(params[:page]).per(1000)
        when 'guid'
          @quiz = Kaminari.paginate_array(Quiz.where(:guid => @item)).page(params[:page]).per(1000)
      end
    else
      @quiz = Kaminari.paginate_array(Quiz.all.desc('_id').select{|q| (q.question_ids.count > 0 || q.quiz_section_ids.map{|qs_id| QuizSection.find(qs_id).question_ids}.flatten.count > 0)}).page(params[:page]).per(1000)
    end
    # @quiz = Kaminari.paginate_array(Quiz.all.desc('_id')).page(params[:page]).per(5000)
  end

  def quiz_questions
    quiz = Quiz.find(params[:id]) rescue nil
    if quiz.present?
      @questions = Question.where(:id.in=>quiz.question_ids)
    else
      @questions = Question.where(sub_question:false).desc('_id').limit(50)
    end
  end

  def get_quizzes
    data = []
    Quiz.all.each do |quiz|
      d = {}
      d['name'] = quiz.name
      d['guid'] = quiz.guid
      d['total_questions'] = quiz.question_ids.count rescue 0
      data << d
    end
    render json: data
  end

  def get_quiz_json
    data = Quiz.get_json_from_s3(params[:guid])
    render json: data
  end

  def create_quiz(question_ids, name, type, duration, instructions,quiz_section_ids)
    if quiz_section_ids.count > 0
      q_ids = quiz_section_ids.map{|qs_id| QuizSection.find(qs_id).question_ids}.flatten
      total_marks = q_ids.map{|id| Question.find(id).default_mark}.sum
    else
      total_marks = question_ids.map{|id| Question.find(id).default_mark}.sum
    end

    quiz = Quiz.create(quiz_language_specific_datas_attributes: [{name:name,description: 'Quiz description',instructions:instructions, language: 'english'}],question_ids:question_ids,quiz_section_ids:quiz_section_ids, type:type, player:type, total_marks:total_marks, total_time:duration)
    quiz.key = "/quiz_zips/#{quiz.guid}.zip"
    quiz.file_path = Rails.root.to_s + "/public/quiz_zips/#{quiz.guid}.zip"
    quiz.save!
    return quiz
  end

  def migrate_quiz
    @publisher_question_bank_ids = PublisherQuestionBank.all
  end

  def process_migrate_quiz
    response = Quiz.migrate_quizzes(params[:name],params[:publisher_question_bank_id])
    respond_to do |format|
      format.html { redirect_to assessment_migrate_quiz_path, notice: response}
    end
  end

  def bulk_migrate_quizzes
    errors = []
    csv = CSV.parse(params[:file].read, :headers => true)
    csv.each do |row|
      begin
        Quiz.migrate_quizzes(row[0],params[:publisher_question_bank_id])
      rescue
        errors << row
      end
    end
    if errors.any?
      errFile ="errors_#{Date.today.strftime('%d%b%y')}.csv"
      errors.insert(0, 'guid'.split(','))
      errCSV = CSV.generate do |csv|
        errors.each {|row| csv << row}
      end
      send_data errCSV,
                :type => 'text/csv; charset=iso-8859-1; header=present',
                :disposition => "attachment; filename=#{errFile}.csv"
    else
      flash[:notice] = 'Quizzes successfully migrated'
      redirect_to assessment_migrate_quiz_path
    end
  end

  def zip_upload_question
    @publisher_question_banks = PublisherQuestionBank.all
    @quiz_types = [['All Types', 'all_types'],['Concept Practice Objective' ,'concept_practice_objective'],['Concept Test Objective' ,'concept_test_objective'],['Concept Practice Subjective' ,'concept_practice_subjective'],['Concept Test Subjective' ,'concept_test_subjective'],['Challenge Test Objective' ,'challenge_test_objective'],['Challenge Test Subjective' ,'challenge_test_subjective'],['Chapter Practice Objective' ,'chapter_practice_objective'],['Chapter Test Objective' ,'chapter_test_objective'],['Chapter Practice Subjective' ,'chapter_practice_subjective'],['Chapter Test Subjective' ,'chapter_test_subjective'],['Challenge Test' ,'challenge test'], ['Subjective', 'subjective'], ['Try Out', 'tryout'], ['Concept Practice', 'concept_practice'],['Subjective Practice','subjective_practice']]
  end

  def post_zip_upload_question
    zip_name = "Sample.zip"
    zip_path = "/home/inayath/edutor/assessment_app/public/zip_uploads/1/"
    extract_dir = "/home/inayath/edutor/assessment_app/public/zip_uploads/1/Maths-F2-C9-1-MCQ-EN"
    etx_file = Dir[extract_dir+"/"+'*.etx'][0]

    publisher_question_bank_id = params[:publisher_question_bank_id] rescue (PublisherQuestionBank.first.id.to_s)
    zip_name = params['zip_file'].original_filename rescue 'Sample.zip'

    if params['quiz_or_questions'] == 'Create Only Questions'
      only_questions = true
      user_id = 100 #to know only uploaded questions
    else
      only_questions = false
      user_id = 1
    end

    institute_name = PublisherQuestionBank.get_institute_name(params['publisher_question_bank_id'])
    tags_db_id = PublisherQuestionBank.get_tags_db_id(params['publisher_question_bank_id'])

    zip_path = File.join(Rails.root.to_s,"public/zip_uploads/#{user_id}/") #"/home/inayath/edutor/assessment/public/zip_uploads/1/"
    FileUtils.mkdir_p zip_path unless Dir.exists?(zip_path)
    file_path = zip_path+zip_name
    File.open(file_path, "wb") { |f| f.write(params[:zip_file].read) }

    extract_dir = zip_path + zip_name.gsub('.zip','')
    # FileUtils.mkdir_p (extract_dir)

    Archive::Zip.extract(file_path, zip_path)

    tags_not_present = []
    question_wise_tags_not_present = []

    if (Dir[extract_dir+"/"+'*.etx'])!=[]
      Dir[extract_dir+"/"+'*.etx'].each do |etx_file|
        file = File.open(etx_file)
        etx = Nokogiri::XML(file)
        test_paper = etx.xpath("/assessment")
        tags_not_present_data = Question.verify_tags(test_paper,tags_db_id)
        tags_not_present += tags_not_present_data[0]
        question_wise_tags_not_present += tags_not_present_data[1]
      end

      logger.info "tags not present -- #{tags_not_present} --------- question_wise_tags_not_present  ---- #{question_wise_tags_not_present}"

      if (tags_not_present.count == 0) && (question_wise_tags_not_present.count == 0)
        Dir[extract_dir+"/"+'*.etx'].each do |etx_file|
          process_etx(etx_file,user_id, publisher_question_bank_id,params[:name], false, params[:type],institute_name,tags_db_id,only_questions) #/home/inayath/edutor/assessment_app/public/zip_uploads/1/Maths-F2-C9-1-MCQ-EN/Maths-F2-C9-1-MCQ-EN.etx
        end
      else
        logger.info "Tags not present -------------------------------- #{tags_not_present}"
        raise Exception.new("Following tags are not present #{tags_not_present} and Following questions do not have the compulsory 5 tags -> #{question_wise_tags_not_present} ")
      end
    end

    # FileUtils.rm_rf(extract_dir)

    respond_to do |format|
      format.html { redirect_to assessment_zip_upload_question_path, notice: 'Quiz was successfully created.'}
    end
  end

  def process_etx(etx_file, user_id, publisher_question_bank_id,quiz_name, hidden=false, type,institute_name,tags_db_id,only_questions)
    s3_path = 'question_images/' #"learnflix-question-images/"
    master_dir = (File.dirname etx_file) + "/" # "/home/inayath/edutor/assessment/public/zip_uploads/1/Maths-F2-C9-1-MCQ-EN/"
    images_dir = etx_file.split('/').last.split('.').first + '_files' #"Maths-F2-C9-1-MCQ-EN_files"
    publisher_question_bank = PublisherQuestionBank.find(publisher_question_bank_id)
    file = File.open(etx_file)
    etx = Nokogiri::XML(file)
    test_paper = etx.xpath("/assessment")
    quiz_name = test_paper.xpath("name").inner_text
    duration = test_paper.xpath("time").inner_text
    instructions = test_paper.xpath("instructions").inner_text
    question_ids = []
    quiz_section_ids = []

    are_sections_present = (test_paper.xpath("section").count > 0)
    if are_sections_present
      test_paper.xpath("section").each do |section|
        quiz_section_name = section.xpath("name").inner_text
        quiz_section_instructions = section.xpath("instructions").inner_text

        quiz_section_question_ids = []
        section.xpath("group_questions").each do |group_ques|
          question = Question.create_group_question(user_id, group_ques,publisher_question_bank_id,s3_path,master_dir,images_dir,institute_name,tags_db_id)
          quiz_section_question_ids << question._id
        end

        section.xpath("question_set").each do |ques|
          question = Question.create_simple_question(user_id, ques,publisher_question_bank_id, s3_path,master_dir,images_dir,institute_name,tags_db_id)
          quiz_section_question_ids << question._id
        end

        quiz_section = QuizSection.create(question_ids:quiz_section_question_ids,quiz_section_language_specific_datas_attributes: [{name:quiz_section_name,instructions:quiz_section_instructions, language: 'english'}])

        quiz_section_ids << quiz_section.id.to_s
      end
    else
      test_paper.xpath("group_questions").each do |group_ques|
        question = Question.create_group_question(user_id, group_ques,publisher_question_bank_id,s3_path,master_dir,images_dir,institute_name,tags_db_id)
        question_ids << question._id
      end

      test_paper.xpath("question_set").each do |ques|
        question = Question.create_simple_question(user_id, ques,publisher_question_bank_id, s3_path,master_dir,images_dir,institute_name,tags_db_id)
        question_ids << question._id
      end
    end

    # publisher_question_bank.attributes = {question_ids:(publisher_question_bank.question_ids + question_ids)}
    # publisher_question_bank.save!

    if !only_questions
      quiz = create_quiz(question_ids,quiz_name, type,duration, instructions,quiz_section_ids)
      if are_sections_present
        quiz_section_ids.each do |qs_id|
          qs = QuizSection.find(qs_id)
          qs.quiz_id = quiz.id.to_s
          qs.save!
        end
      end
    end

    puts ("Successfully updated #{question_ids.count} -- #{question_ids}")
  end

  ######################################################

  def get_all_assessment_attempts
    result_data = {}
    attempts = []
    assessments = []
    a = {}
    data = QuizAttemptData.where("data.book_id"=>params[:book_id],:user_id=>current_user.id)
    # data = QuizAttemptData.where(:user_id=>current_user.id)
    if data.present?
      data.each do |d|
        quiz = Quiz.where(:guid=>d.data["asset_download_id"]).last
        s = {}
        ad = {}
        s["attemptId"] = d._id.to_s
        s["attemptedAt"] = d.data["start_time"]
        s["assessmentType"] = d.data["player_subtype"]
        s["assessmentName"] = quiz.name rescue ""
        s["assessmentGuid"] = d.data["asset_download_id"]
        s["uri_path"] = TocData.where(:downloadId=>d.data["asset_download_id"]).last.path rescue ""
        attempts << s
        if !a.keys.include? d.data["asset_download_id"]
          a[d.data["asset_download_id"]] = d.data["asset_download_id"]
          ad["assessmentGuid"] = d.data["asset_download_id"]
          ad["uri_path"] = s["uri_path"]
          assessments  <<  ad
        end
      end
    end
    result = {:assessments=>assessments,:attempts=>attempts}
    render json: result
  end

  def get_assessment_attempt_by_attempt_id
    result = {}
    attempt_data  = QuizAttemptData.where("_id"=>params[:attempt_id]).last
    quiz_data = Quiz.where(:guid=>attempt_data.data["asset_download_id"]).last.quiz_json
    result["attemptData"] = attempt_data
    result["quizData"] = quiz_data
    render json: result
  end


  def get_image_download_url
    redirect_to ((Image.where(key: "question_images/#{params['question_id']}/#{params['image_name']}.jpg")[0].get_download_url) rescue "http://13.234.165.191/icons/broken_image.jpg")
  end

  def get_user_attempt_analytics
    data = QuizAttemptData.get_user_attempt_analytics(params[:guid],current_user.id)
    render json: data
  end

  def get_user_attempt_analytics_v1
    data = QuizAttemptData.get_user_attempt_analytics_v1(params[:guid],current_user.id)
    render json: data
  end

  def get_user_quiz_attempt_topic_details
    data = QuizAttemptData.get_user_quiz_attempt_topic_details(params[:guid],current_user.id)
    render json: data
  end

  def get_quiz_question_attempts
    data = QuizAttemptData.get_quiz_question_attempts(params[:guid],current_user.id)
    render json: data
  end

  def get_given_quiz_analytics
    data = QuizAttemptData.get_given_quiz_analytics(params[:assessment_guids],current_user.id)
    render json: data
  end

  def get_given_quiz_topic_analytics
    data = QuizAttemptData.get_given_quiz_topic_analytics(params[:assessment_guids],current_user.id)
    render json: data
  end

  def get_group_assessment_analytics
    publish_id = ""
    group = ""
    data = QuizAttemptData.get_group_assessment_analytics(params[:guid],publish_id,group)
    render json: data
  end

  def get_group_assessment_rank_data
    publish_id = ""
    group = ""
    data = QuizAttemptData.get_group_assessment_rank_data(params[:guid],publish_id,group)
    render json: data
  end

  def get_group_assessment_subject_details
    publish_id = ""
    group = ""
    data = QuizAttemptData.get_group_assessment_subject_details(params[:guid],publish_id,group)
    render json: data
  end

  def get_assessment_group_topic_details
    publish_id = ""
    group = ""
    data = QuizAttemptData.get_assessment_group_topic_details(params[:guid],publish_id,group)
    render json: data
  end

  def get_question_error_analytics
    publish_id = ""
    group = ""
    data = QuizAttemptData.get_question_error_analytics(params[:guid],publish_id,group)
    render json: data
  end

  private
  def quiz_params
    params.require(:quiz).permit(:type,:_id,:quiz_section_ids,:final,quiz_language_specific_datas_attributes: [:name, :instructions, :description,:language])
  end
  # {:question_answers => [:answer_hindi, :answer_english, :fraction]},


  def quiz_section_params
    params.require(:quiz_section).permit(
        quiz_section_language_specific_datas_attributes: [
            :id, :name, :instructions, :_destroy
        ]
    )
  end

  def publish_params
    params.require(:publish).permit(:quiz_type,:password,:shuffle_options,:shuffle_questions,:pause,:evaluate_server_side,:key_update,:time_open,:time_close,:show_score_after,:show_answers_after,:max_no_of_attempts,:published_by,:published_on,:group_ids,:user_ids,:guid,:message_subject,:message_body,:qui_id,:is_cancelled)

  end
end
