class QuizzesController < ApplicationController

  skip_before_action :authenticate_user!, except:[:challenge_test_attempt_data, :get_all_quiz_attempt_datas, :get_quiz_attempt_data_by_id]

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
    @quiz.upload_zip
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

  def show

  end

  def all_quizzes
    @quiz = Kaminari.paginate_array(Quiz.all.desc('_id')).page(params[:page]).per(5000)
  end

  def quiz_questions
    quiz = Quiz.find(params[:id])
    @questions = Question.where(:id.in=>quiz.question_ids)
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

  end

  def process_migrate_quiz
    response = Quiz.migrate_quizzes(params[:name])
    respond_to do |format|
      format.html { redirect_to assessment_migrate_quiz_path, notice: response}
    end
  end

  def bulk_migrate_quizzes
    errors = []
    csv = CSV.parse(params[:file].read, :headers => true)
    csv.each do |row|
      begin
        Quiz.migrate_quizzes(row[0])
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
    zip_name = "Maths-F2-C9-1-MCQ-EN.zip"
    zip_path = "/home/inayath/edutor/assessment_app/public/zip_uploads/1/"
    extract_dir = "/home/inayath/edutor/assessment_app/public/zip_uploads/1/Maths-F2-C9-1-MCQ-EN"

    user_id = 1
    publisher_question_bank_id = params[:publisher_question_bank_id] rescue (PublisherQuestionBank.first._id)

    zip_name = params[:zip_file].original_filename

    zip_path = File.join(Rails.root.to_s,"public/zip_uploads/#{user_id}/") #"/home/inayath/edutor/assessment/public/zip_uploads/1/"
    FileUtils.mkdir_p zip_path unless Dir.exists?(zip_path)
    file_path = zip_path+zip_name
    File.open(file_path, "wb") { |f| f.write(params[:zip_file].read) }

    extract_dir = zip_path + zip_name.gsub('.zip','')
    FileUtils.mkdir_p (extract_dir)

    Archive::Zip.extract(file_path, extract_dir)

    tags_not_present = []
    question_wise_tags_not_present = []

    if (Dir[extract_dir+"/"+'*.etx'])!=[]
      Dir[extract_dir+"/"+'*.etx'].each do |etx_file|
        file = File.open(etx_file)
        etx = Nokogiri::XML(file)
        test_paper = etx.xpath("/ignitor_questions")
        tags_not_present_data = verify_tags(test_paper)
        tags_not_present += tags_not_present_data[0]
        question_wise_tags_not_present += tags_not_present_data[1]
      end
      logger.info "2222222222222222222222222"
      logger.info tags_not_present
      logger.info question_wise_tags_not_present

      if (tags_not_present.count == 0) && (question_wise_tags_not_present.count == 0)
        Dir[extract_dir+"/"+'*.etx'].each do |etx_file|
          process_etx(etx_file,user_id, publisher_question_bank_id,params[:name], false, params[:type]) #/home/inayath/edutor/assessment_app/public/zip_uploads/1/Maths-F2-C9-1-MCQ-EN/Maths-F2-C9-1-MCQ-EN.etx
        end
      else
        logger.info "Tags not present -------------------------------- #{tags_not_present}"
        raise Exception.new("Following tags are not present #{tags_not_present} and Following questions do not have the compulsory 5 tags -> #{question_wise_tags_not_present} ")
      end
    end

    FileUtils.rm_rf(extract_dir)

    respond_to do |format|
      format.html { redirect_to assessment_zip_upload_question_path, notice: 'Quiz was successfully created.'}
    end
  end

  def verify_tags(test_paper)
    tag_not_present = []
    question_wise_tags_not_present = []

    (test_paper.xpath("group_questions") + test_paper.xpath("question_set")).each_with_index do |ques,i|
      tag_keys = get_question_tag_keys(ques)

      if tag_keys.count == 5
        tag_keys.each do |key|
          if !TagsServer.get_tag_guid_by_key(key).present?
            tag_not_present << key
          end
        end
      else
        tag_not_present = ["course", "grade", "subject", "chapter", "concept"] - tag_keys
      end

      if tag_keys.count != 5
        question_tag_not_present = {}
        question_tag_not_present['id'] = i+1
        question_tag_not_present['type'] = ques.xpath("qtype").attr("value").to_s rescue ''
        question_tag_not_present['tags_not_present'] = ["course", "grade", "subject", "chapter", "concept"] - tag_keys
        question_wise_tags_not_present << question_tag_not_present
      end
    end
    return [tag_not_present.uniq,question_wise_tags_not_present]
  end

  def get_question_tag_keys(ques)
    must_present_tag_names_for_each_question = ["course", "grade", "subject", "chapter", "concept"]
    five_compulsory_tags_data = {}
    ques.xpath("itags/itag").each do |tag|
      name = tag.attr("name").to_s
      value = tag.attr("value").to_s
      five_compulsory_tags_data[name] = value if must_present_tag_names_for_each_question.include? name
    end

    if five_compulsory_tags_data.keys.count == 5
      five_compulsory_tags_data_1 = {}
      five_compulsory_tags_data.keys.each_with_index do |k,i|
        five_compulsory_tags_data_1[must_present_tag_names_for_each_question[i]] = five_compulsory_tags_data[must_present_tag_names_for_each_question[i]]
      end
      key = ''
      five_compulsory_tags_data = {}
      five_compulsory_tags_data_1.keys.each_with_index do |k,i|
        if i!= 0
          key = key + '_' +five_compulsory_tags_data_1[k]
          five_compulsory_tags_data[k] = key
        else
          key = five_compulsory_tags_data_1[k]
          five_compulsory_tags_data[k] = key
        end
      end
      return five_compulsory_tags_data.values
    else
      return five_compulsory_tags_data.keys
    end
  end

  def process_etx(etx_file, user_id, publisher_question_bank_id,quiz_name, hidden=false, type)
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
          question = create_group_question(user_id, group_ques,publisher_question_bank_id,s3_path,master_dir,images_dir)
          quiz_section_question_ids << question._id
        end

        section.xpath("question_set").each do |ques|
          question = create_simple_question(user_id, ques,publisher_question_bank_id, s3_path,master_dir,images_dir)
          quiz_section_question_ids << question._id
        end

        quiz_section = QuizSection.create(question_ids:quiz_section_question_ids,quiz_section_language_specific_datas_attributes: [{name:quiz_section_name,instructions:quiz_section_instructions, language: 'english'}])

        quiz_section_ids << quiz_section.id.to_s
      end
    else
      test_paper.xpath("group_questions").each do |group_ques|
        question = create_group_question(user_id, group_ques,publisher_question_bank_id,s3_path,master_dir,images_dir)
        question_ids << question._id
      end

      test_paper.xpath("question_set").each do |ques|
        question = create_simple_question(user_id, ques,publisher_question_bank_id, s3_path,master_dir,images_dir)
        question_ids << question._id
      end
    end

    # publisher_question_bank.attributes = {question_ids:(publisher_question_bank.question_ids + question_ids)}
    # publisher_question_bank.save!

    quiz = create_quiz(question_ids,quiz_name, type,duration, instructions,quiz_section_ids)
    if are_sections_present
      quiz_section_ids.each do |qs_id|
        qs = QuizSection.find(qs_id)
        qs.quiz_id = quiz.id.to_s
        qs.save!
      end
    end

    puts ("Successfully updated #{question_ids.count} -- #{question_ids}")
  end

  def create_simple_question(user_id, ques,publisher_question_bank_id, s3_path,master_dir,images_dir)
    question_data = get_simple_question_hash(user_id,ques, publisher_question_bank_id)
    question = Question.create_question(question_data)
    update_image_path(question._id,s3_path)
    copy_question_images(question._id,master_dir,images_dir)
    return question
  end

  def update_image_path(ques_id,s3_path)
    question = Question.find(ques_id)
    question.question_language_specific_datas.each do |qlsd|
      qlsd.update_attributes(question_text:update_img_src(qlsd.question_text,s3_path,ques_id), general_feedback:update_img_src(qlsd.general_feedback,s3_path,ques_id),hint:update_img_src(qlsd.hint,s3_path,ques_id),actual_answer:update_img_src(qlsd.actual_answer,s3_path,ques_id))
    end
    if question.qtype == 'MmcqQuestion' || question.qtype == 'SmcqQuestion' || question.qtype == 'AssertionReasonQuestion' || question.qtype == 'McqMatrixQuestion' || question.qtype == 'TrueFalseQuestion'
      question.question_answers.each do |qa|
        qa.update_attributes(answer_english:update_img_src(qa.answer_english,s3_path,ques_id))
      end
    end
  end

  def update_img_src(text,s3_path,ques_id)
    if text.present?
      replacement_paths = []
      Nokogiri::HTML(text).css('img').map{ |i| i['src'] }.each do |img|
        replacement_paths << (img.reverse.split('/', 2).map(&:reverse).reverse)[0]
      end
      replacement_paths.uniq.each do |rp|
        text = text.gsub(rp, s3_path+ques_id)
      end
      ['.png', '.wmz'].each do |f|
        text = text.gsub(f, '.jpg')
      end
    else
      text = ''
    end
    return text
  end

  def copy_question_images(ques_id,master_dir, images_dir)
    ques_images = []
    question = Question.find(ques_id)
    question.question_language_specific_datas.each do |qlsd|
      [qlsd.question_text,qlsd.general_feedback,qlsd.hint,qlsd.actual_answer].each do |text|
        Nokogiri::HTML(text).css('img').map{ |i| i['src'] }.each do |img|
          ques_images << img.split("/").last
        end
      end
    end

    if question.qtype == 'MmcqQuestion' || question.qtype == 'SmcqQuestion' || question.qtype == 'AssertionReasonQuestion' || question.qtype == 'McqMatrixQuestion' || question.qtype == 'TrueFalseQuestion'
      question.question_answers.each do |qa|
        Nokogiri::HTML(qa.answer_english).css('img').map{ |i| i['src'] }.each do |img|
          ques_images << img.split("/").last
        end
      end
    end

    ques_images = ques_images.uniq
    image_names = ques_images.map{|n| n.downcase.split('.')[0]}
    image_ids = []

    dir_path = Rails.root.to_s + "/public/question_images/#{ques_id}/"
    Dir["#{master_dir}/#{images_dir}/*"].each do |img|
      index = image_names.index(File.basename(img).split('.')[0].downcase)

      if index.present?
        FileUtils.mkdir_p(dir_path) unless File.exists?(dir_path)
        # copying to public folder
        img_name = (ques_images[index]).split('.')[0] + ".jpg"
        image = Magick::Image.read(img).first
        image.write(dir_path+img_name)

        # creating Image reference for S3
        if_img = Image.where(key:"question_images/#{ques_id}/#{img_name}")[0]
        image_ids << (Image.create(name: img_name, key: "question_images/#{ques_id}/#{img_name}", file_path:(dir_path+img_name))).guid if !if_img.present?
      end

    end
    question.image_ids = image_ids
    question.save!
    question.upload_images
  end

  def create_group_question(user_id, group_ques,publisher_question_bank_id,s3_path,master_dir,images_dir)
    question_data = get_group_question_hash(user_id,group_ques, publisher_question_bank_id,s3_path,master_dir,images_dir)
    question = Question.create_question(question_data)
    update_image_path(question._id,s3_path)
    copy_question_images(question._id,master_dir,images_dir)
    return question
  end

  def get_group_question_hash(user_id, group_ques, publisher_question_bank_id,s3_path,master_dir,images_dir)
    data = {}
    data['publisher_question_bank_ids'] = [publisher_question_bank_id]
    data['question_language_specific_datas_attributes'] = []
    d = {}
    d['question_text'] = group_ques.xpath("instruction").inner_text rescue ''
    d['language'] = Language::ENGLISH

    data['question_language_specific_datas_attributes'] << d
    data['qtype'] = 'PassageQuestion'
    data['created_by'] = user_id
    data['tag_ids'] = []

    tag_keys = get_question_tag_keys(group_ques)
    tag_keys.each do |key|
      data['tag_ids'] << TagsServer.get_tag_guid_by_key(key)
    end

    group_ques.xpath("itags/itag").each do |tag|
      name = tag.attr("name").to_s
      value = tag.attr("value").to_s

      if ["difficulty_level", "blooms_taxonomy"].include? name
        data['tag_ids'] << TagsServer.get_tag_guid(name, value)
      end
    end

    data['question_guids'] = []
    group_ques.xpath("question_set").each do |ques|
      child_question = create_simple_question(user_id, ques,publisher_question_bank_id, s3_path,master_dir,images_dir)
      data['question_guids'] << child_question.guid
    end
    data['default_mark'] = data['question_guids'].map{|guid| Question.where(guid:guid)[0].default_mark}.sum
    return data
  end

  def get_simple_question_hash(user_id, ques, publisher_question_bank_id)
    data = {}
    data['publisher_question_bank_ids'] = [publisher_question_bank_id]

    data['question_language_specific_datas_attributes'] = []
    d = {}
    d['question_text'] = ques.xpath("question/question_text").inner_text
    d['general_feedback'] = ques.xpath("question/solution")[0].inner_text rescue ''
    d['actual_answer'] = ques.xpath("question/actual_answer").inner_text rescue ''
    d['hint'] = ques.xpath("question/hint").inner_text rescue ''
    d['language'] = Language::ENGLISH

    data['question_language_specific_datas_attributes'] << d

    data['qtype'] = get_qtype(ques.xpath("qtype").attr("value").to_s.downcase)
    data['default_mark'] = ques.xpath("score").attr("value").to_s.to_i rescue 1
    data['penalty'] = ques.xpath("penalty").attr("value").to_s.to_i rescue 0

    data['created_by'] = user_id

    if ['SmcqQuestion', 'MmcqQuestion', 'TrueFalseQuestion', 'McqMatrixQuestion', 'AssertionReasonQuestion'].include? data['qtype']
      data['question_answers_attributes'] = []
      fraction = ques.xpath("question/answer").attr("value").to_s.split(",") if !ques.xpath("question/answer").nil?
      ques.xpath("question/option").each_with_index do |option, index|
        data['question_answers_attributes'] << get_question_answer_hash(fraction, index, option)
      end
    elsif ['FibQuestion', 'FibIntegerQuestion'].include? data['qtype']
      data['question_fill_blanks_attributes'] = []
      ques.xpath("question/options_fib").each do |option|
        data['question_fill_blanks_attributes'] << get_question_fill_blank_hash(option)
      end
    end

    data['tag_ids'] = []

    tag_keys = get_question_tag_keys(ques)
    tag_keys.each do |key|
      data['tag_ids'] << TagsServer.get_tag_guid_by_key(key)
    end

    ques.xpath("itags/itag").each do |tag|
      name = tag.attr("name").to_s
      value = tag.attr("value").to_s

      if ["difficulty_level", "blooms_taxonomy"].include? name
        data['tag_ids'] << TagsServer.get_tag_guid(name, value)
      end
    end
    return data
  end

  def get_question_answer_hash(fraction, index, option)
    data1 = {}
    is_correct_option = 0
    if fraction.length == 1
      is_correct_option = option_is_correct?(index, fraction.first) ? 1 : 0
    else
      if fraction.include?(%w(A B C D E)[index]) or fraction.include?(%w(1 2 3 4 5)[index])
        is_correct_option = 1
      else
        is_correct_option = 0
      end
    end
    data1['answer_english'] = option.xpath("option_text").inner_text
    data1['fraction'] = is_correct_option
    data1['feedback'] = option.xpath("feedback").inner_text
    return data1
  end

  def option_is_correct?(index,fraction)
    case index+1
      when 1 then true if (fraction == "A" or fraction == "1")
      when 2 then true if (fraction == "B" or fraction == "2")
      when 3 then true if (fraction == "C" or fraction == "3")
      when 4 then true if (fraction == "D" or fraction == "4")
      when 5 then true if (fraction == "E" or fraction == "5")
      else
        false
    end
  end

  def get_question_fill_blank_hash(option)
    data = {}
    data['answer'] = []
    option.xpath("option_blank").each do |option_blank|
      data['answer'] << option_blank.inner_text
    end
    data['case_sensitive'] = option.attr("value").to_s.to_i
    return data
  end

  def get_qtype(qtype)
    if qtype == "smcq"
      "SmcqQuestion"
    elsif qtype == "mmcq"
      "MmcqQuestion"
    elsif qtype == "fib"
      "FibQuestion"
    elsif qtype == "tof" || qtype == "truefalse"
      "TrueFalseQuestion"
    elsif qtype == "fibinteger"
      "FibIntegerQuestion"
    elsif qtype == "mcqmatrix"
      "McqMatrixQuestion"
    elsif qtype == "assertionreason"
      "AssertionReasonQuestion"
    elsif qtype == "saq" || qtype == "laq" || qtype == "vsaq"
      "SubjectiveQuestion"
    end
  end

  def get_all_assessment_attempts
    result = []
    data = QuizAttemptData.where("data.book_id"=>params[:book_id],:user_id=>current_user.id)
    if data.present?
      s = {}
      data.each do |d|
        quiz = Quiz.where(:guid=>d.data["asset_download_id"]).last
        s["attemptId"] = d._id.to_s
        s["attemptedAt"] = d.data["start_time"]
        s["assessmentType"] = d.data["player_subtype"]
        s["assessmentName"] = quiz.name rescue ""
        s["assessmentGuid"] = d.data["asset_download_id"]
        s["tags"] = {}
        result << s
      end
    end
    render json: result
  end


  def get_assessment_attempt_by_attempt_id
    result = {}
    attempt_data  = QuizAttemptData.where("_id"=>params[:attemptId]).last
    quiz_data = Quiz.where(:guid=>d.data["asset_download_id"]).last.quiz_json
    result["attemptData"] = attempt_data
    result["quizData"] = quiz_data
    render json: result
  end


  private
  def quiz_params
    params.require(:quiz).permit(:final,quiz_language_specific_datas_attributes: [:name])
  end
end
