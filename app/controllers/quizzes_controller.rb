class QuizzesController < ApplicationController

  skip_before_action :authenticate_user!     #, only: [:show, :index]

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
      qad = QuizAttemptData.where("data.guid"=>{:$in=>[guid]},user_id:params[:user_id]).last

      if quiz.present?
        (JSON.parse(quiz.focus_area)).each do |fa|
          d[fa['guid']] ||= {}
          d[fa['guid']]['name'] = fa['name']
          d[fa['guid']]['total_questions'] ||= []
          d[fa['guid']]['total_questions'] << fa['questionIds'].uniq.map!{|e| e.to_i}
        end
      end

      if qad.present?
        correct_ids << qad.data['correct']
        in_correct_ids << qad.data['incorrect']
        skipped_ids << qad.data['skipped_questions']
        skipped_ids << qad.data['unattempted'] #logic changed here (skipped + un_attempted)
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

  def get_assessments_attempted_count
    data = {}
    assessment_ids = params[:assessment_ids]
    uniq_count = QuizAttemptData.where("data.guid"=>{:$in=>assessment_ids},user_id:params[:user_id]).group_by{|i| i.data["guid"]}.count

    data['attempted'] = uniq_count
    data['un_attempted'] = assessment_ids.count - uniq_count
    data['total'] = assessment_ids.count
    render json: data
  end

  def get_assessments_active_duration
    data = {}
    assessment_ids = params[:assessment_ids]
    duration_sum = QuizAttemptData.where("data.guid"=>{:$in=>assessment_ids},user_id:params[:user_id],"data.player_subtype"=>{ :$ne=> "tryout" }).map{|qad| qad.data['active_duration']}.sum rescue 0

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
      qad = QuizAttemptData.where("data.guid"=>{:$in=>[guid]},user_id:params[:user_id]).last

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
          qad = QuizAttemptData.where("data.guid"=>{:$in=>[guid]},user_id:params[:user_id]).last

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
    qad = QuizAttemptData.where("data.guid"=>{:$in=>[params[:guid]]},user_id:params[:user_id].to_s).last
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
    if @quiz.update_attributes(quiz_language_specific_datas: [name: q_params.values[0]['name']], final: quiz_params[:final])
      redirect_to assessment_all_quizzes_path
    else
      render 'edit'
    end
  end

  def get_focus_area
    quiz = (Quiz.where(:guid.in => [params[:guid]]))[0]
    if quiz.present?
      render json: quiz.focus_area
    else
      render json: {}
    end
  end

  def update_focus_area
    quiz = (Quiz.where(:guid.in => [params[:guid]]))[0]
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

  def process_quiz_attempt_data
    data = {"launch_path"=>"", "guid"=>"asset_guid", "start_time"=>"time when the asset is opened", "active_duration"=>"less than or equal to end_time - start_time", "end_time"=>"time when the asset is closed", "book_id"=>"book_guid", "player"=>"player used to launch", "item_type"=>"self explanatory", "display_name"=>"self explanatory", "time_zone"=>"self explanatory", "ip_address"=>"self explanatory", "user_agent"=>"android/windows/ios/web", "package_id"=>"self explanatory", "device_id"=>"self explanatory", "tags"=>"self explanatory", "score"=>"123", "attempted"=>[], "correct"=>[], "timeline"=>[{"question_id"=>12345, "sessions"=>[{"start_time"=>123456789, "end_time"=>123456799, "data"=>{"extras"=>"can have key value pair, for mcq option_selecte:a, for fib answer:abc...etc"}}]}, {"question_id"=>6789, "sessions"=>[{"start_time"=>123476789, "end_time"=>123458799, "data"=>{"extras"=>"can have key value pair, for mcq option_selected:a, for fib answer:abc...etc"}}]}]}

    quiz = Quiz.where(:guid.in=>data['guid'])[0]

    quiz_attempt_data = {}
    quiz_attempt_data['guid'] = data['guid']
    quiz_attempt_data['start_time'] = data['start_time']
    quiz_attempt_data['end_time'] = data['end_time']
    quiz_attempt_data['active_duration'] = data['active_duration']
    quiz_attempt_data['publish_id'] = data['publish_id']
    quiz_attempt_data['book_id'] = data['book_id']
    quiz_attempt_data['total_marks'] = quiz.total_marks

    question_attempts_attributes = []

    data['timeline'].each do |q_data|
      question = Question.where(:guid.in=>q_data['question_id'])[0]
      question_attempt_data = {}
      question_attempt_data['question_attributes'] = question
      question_attempt_data['qtype'] = question.qtype

    end

  end

  def home

  end

  def show

  end

  def all_quizzes
    @quiz = Quiz.all.order("created_at DESC")
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

  def zip_upload_question
    @publisher_question_banks = PublisherQuestionBank.all
    @quiz_types = [['All Types', 'all_types'],['Concept Practice Objective' ,'concept_practice_objective'],['Concept Test Objective' ,'concept_test_objective'],['Concept Practice Subjective' ,'concept_practice_subjective'],['Concept Test Subjective' ,'concept_test_subjective'],['Challenge Test Objective' ,'challenge_test_objective'],['Challenge Test Subjective' ,'challenge_test_subjective'],['Chapter Practice Objective' ,'chapter_practice_objective'],['Chapter Test Objective' ,'chapter_test_objective'],['Chapter Practice Subjective' ,'chapter_practice_subjective'],['Chapter Test Subjective' ,'chapter_test_subjective'],['Challenge Test' ,'challenge test'], ['Subjective', 'subjective'], ['Try Out', 'tryout'], ['Concept Practice', 'concept_practice']]
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
      # format.json { render json: @zip_upload.errors, status: :unprocessable_entity }
    end
  end

  def verify_tags(test_paper)
    all_tags = []
    tag_not_present = []
    must_present_tag_names_for_each_question = ["course", "grade", "subject", "chapter", "concept"]
    question_wise_tags_not_present = []
    test_paper.xpath("group_questions").each_with_index do |group_ques,i|
      tag_names = []
      group_ques.xpath("itags/itag").each do |tag|
        name = tag.attr("name").to_s
        value = tag.attr("value").to_s
        d = {}
        d['name'] = name
        d['value'] = value
        tag_names << name
        all_tags << d
        if !TagsServer.get_tag_guid(name, value).present?
          tag_not_present << d
        end
      end
      absent_tags = must_present_tag_names_for_each_question - tag_names
      if absent_tags.count > 0
        question_tag_not_present = {}
        question_tag_not_present['id'] = i+1
        question_tag_not_present['type'] = 'group_questions'
        question_tag_not_present['tags_not_present'] = absent_tags
        question_wise_tags_not_present << question_tag_not_present
      end
    end

    test_paper.xpath("question_set").each_with_index do |ques,i|
      tag_names = []
      ques.xpath("itags/itag").each do |tag|
        name = tag.attr("name").to_s
        value = tag.attr("value").to_s
        d = {}
        d['name'] = name
        d['value'] = value
        tag_names << name
        all_tags << d
        if !TagsServer.get_tag_guid(name, value).present?
          tag_not_present << d
        end
      end
      absent_tags = must_present_tag_names_for_each_question - tag_names
      if absent_tags.count > 0
        question_tag_not_present = {}
        question_tag_not_present['id'] = i+1
        question_tag_not_present['type'] = 'question_set'
        question_tag_not_present['tags_not_present'] = absent_tags
        question_wise_tags_not_present << question_tag_not_present
      end
    end
    logger.info "All tags - #{all_tags.count} - #{all_tags}"
    return [tag_not_present,question_wise_tags_not_present]
  end

  def process_etx(etx_file, user_id, publisher_question_bank_id,quiz_name, hidden=false, type)
    s3_path = '/question_images/' #"learnflix-question-images/"
    master_dir = (File.dirname etx_file) + "/" # "/home/inayath/edutor/assessment/public/zip_uploads/1/Maths-F2-C9-1-MCQ-EN/"
    images_dir = etx_file.split('/').last.split('.').first + '_files' #"Maths-F2-C9-1-MCQ-EN_files"
    publisher_question_bank = PublisherQuestionBank.find(publisher_question_bank_id)
    file = File.open(etx_file)
    etx = Nokogiri::XML(file)
    test_paper = etx.xpath("/assessment")
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

    publisher_question_bank.attributes = {question_ids:(publisher_question_bank.question_ids + question_ids)}
    publisher_question_bank.save!

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
      qlsd.update_attributes(question_text:update_img_src(qlsd.question_text,s3_path,ques_id), general_feedback:update_img_src(qlsd.general_feedback,s3_path,ques_id))
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
      Nokogiri::HTML(qlsd.question_text).css('img').map{ |i| i['src'] }.each do |img|
        ques_images << img.split("/").last
      end

      Nokogiri::HTML(qlsd.general_feedback).css('img').map{ |i| i['src'] }.each do |img|
        ques_images << img.split("/").last
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
    FileUtils.mkdir_p(dir_path)
    Dir["#{master_dir}/#{images_dir}/*"].each do |img|
      index = image_names.index(File.basename(img).split('.')[0].downcase)

      if index.present?
        # copying to public folder
        img_name = (ques_images[index]).split('.')[0] + ".jpg"
        image = Magick::Image.read(img).first
        image.write(dir_path+img_name)

        # creating Image reference for S3
        image_ids << (Image.create(name: img_name, key: "/question_images/#{ques_id}/#{img_name}", file_path:(dir_path+img_name))).guid
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
    group_ques.xpath("itags/itag").each do |tag|
      name = tag.attr("name").to_s
      value = tag.attr("value").to_s
      if ["course", "grade", "subject", "chapter", "concept"].include? name
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
    d['language'] = 'english'

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
    ques.xpath("itags/itag").each do |tag|
      name = tag.attr("name").to_s
      value = tag.attr("value").to_s
      if ["course", "grade", "subject", "chapter", "concept"].include? name
        data['tag_ids'] << TagsServer.get_tag_guid(name, value)
      else
        if name == "subjective_lines" && (['SubjectiveQuestion'].include? data['qtype'])
          data['answer_lines'] = value
        else
          data['tag_ids'] << TagsServer.get_tag_guid(name, value)
        end
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

  private
  def quiz_params
    params.require(:quiz).permit(:final,quiz_language_specific_datas_attributes: [:name])
  end
end
