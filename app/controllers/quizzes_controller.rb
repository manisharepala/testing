class QuizzesController < ApplicationController

  def home

  end

  def get_quizzes
    data = []
    Quiz.all.each do |quiz|
      d = {}
      d['name'] = quiz.name
      d['guid'] = quiz.guid
      d['total_questions'] = quiz.question_ids.count
      data << d
    end
    render json: data
  end

  def get_quiz_for_browser
    render json: (Quiz.where(:guid.in => [params[:guid]]))[0].as_json
  end

  def get_quiz_for_app
    quiz = (Quiz.where(:guid.in => [params[:guid]]))[0]

    quiz_zips_dir = Rails.root.to_s + "/public/quiz_zips/"
    zip_name = quiz_zips_dir + "#{quiz.guid}.zip"
    quiz_zip_path = quiz_zips_dir + quiz.guid + "/"

    FileUtils.mkdir_p (quiz_zips_dir) if !Dir.exists?(quiz_zips_dir)
    FileUtils.mkdir_p (quiz_zip_path) if !Dir.exists?(quiz_zip_path)

    question_images_path = Rails.root.to_s + "/public/question_images/"

    # FileUtils.rm_rf Dir.glob("#{dir_path}/*") if dir_path.present?
    quiz.question_ids.each do |id|
      FileUtils.mkdir_p (quiz_zip_path+id)
      FileUtils.cp_r(Dir["#{question_images_path+id}/*"],quiz_zip_path+id)
    end

    File.open(quiz_zip_path+"quiz_data.json","w") do |f|
      f.write((quiz.as_json).to_json)
    end

    Archive::Zip.archive(zip_name, quiz_zip_path)
    send_file zip_name
  end


  def create_quiz(question_ids, name)
    quiz = Quiz.new
    quiz.name = name
    quiz.question_ids = question_ids
    quiz.save
  end

  def zip_upload_question
    @publisher_question_banks = PublisherQuestionBank.all
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

    if (Dir[extract_dir+"/"+'*.etx'])!=[]
      Dir[extract_dir+"/"+'*.etx'].each do |etx_file|
        begin
          ActiveRecord::Base.transaction do
            process_etx(etx_file,user_id, publisher_question_bank_id,zip_name.split('.')[0], false) #/home/inayath/edutor/assessment_app/public/zip_uploads/1/Maths-F2-C9-1-MCQ-EN/Maths-F2-C9-1-MCQ-EN.etx
          end
        rescue Exception => e
          logger.info "Exception in etx uploading....#{e.backtrace}"
        end
      end
    end

    # FileUtils.rm_rf(extract_dir)

    respond_to do |format|
      format.html { redirect_to assessment_zip_upload_question_path}
      # format.json { render json: @zip_upload.errors, status: :unprocessable_entity }
    end
  end

  def process_etx(etx_file, user_id, publisher_question_bank_id,quiz_name, hidden=false)
    s3_path = '/question_images/' #"learnflix-question-images/"
    master_dir = (File.dirname etx_file) + "/" # "/home/inayath/edutor/assessment/public/zip_uploads/1/Maths-F2-C9-1-MCQ-EN/"
    publisher_question_bank = PublisherQuestionBank.find(publisher_question_bank_id)
    file = File.open(etx_file)
    etx = Nokogiri::XML(file)
    test_paper = etx.xpath("/ignitor_questions")
    question_ids = []

    test_paper.xpath("group_questions").each do |group_ques|
      question = create_group_question(user_id, group_ques,publisher_question_bank_id, hidden)
      question_ids << question._id
    end

    test_paper.xpath("question_set").each do |ques|
      question = create_simple_question(user_id, ques,publisher_question_bank_id, s3_path,master_dir)
      question_ids << question._id
    end
    publisher_question_bank.attributes = {question_ids:(publisher_question_bank.question_ids + question_ids)}
    publisher_question_bank.save!

    create_quiz(question_ids,quiz_name)

    puts ("Successfully updated #{question_ids.count} -- #{question_ids}")
  end

  def create_simple_question(user_id, ques,publisher_question_bank_id, s3_path,master_dir)
    question_data = get_simple_question_hash(user_id,ques, publisher_question_bank_id)
    question = Question.create_question(question_data)
    update_image_path(question._id,s3_path)
    copy_question_images(question._id,master_dir)
    return question
  end

  def update_image_path(ques_id,s3_path)
    question = Question.find(ques_id)
    question.update_attributes(question_text:update_img_src(question.question_text,s3_path,ques_id), general_feedback:update_img_src(question.general_feedback,s3_path,ques_id))
    if question.qtype == MmcqQuestion || question.qtype == SmcqQuestion
      question.question_answers.each do |qa|
        qa.update_attributes(answer:update_img_src(qa.answer,s3_path,ques_id))
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
    else
      text = ''
    end
    return text
  end

  def copy_question_images(ques_id,master_dir)
    ques_images = []
    question = Question.find(ques_id)
    Nokogiri::HTML(question.question_text).css('img').map{ |i| i['src'] }.each do |img|
      ques_images << img.split("/").last
    end

    Nokogiri::HTML(question.general_feedback).css('img').map{ |i| i['src'] }.each do |img|
      ques_images << img.split("/").last
    end

    if question.qtype == MmcqQuestion || question.qtype == SmcqQuestion
      question.question_answers.each do |qa|
        Nokogiri::HTML(qa.answer).css('img').map{ |i| i['src'] }.each do |img|
          ques_images << img.split("/").last
        end
      end
    end

    if question.qtype == 'Passage'
      question.questions.each do |q|
        copy_question_images(q._id,master_dir)
      end
    end

    ques_images = ques_images.uniq
    image_names = ques_images.map{|n| n.downcase.split('.')[0]}

    dir_path = Rails.root.to_s + "/public/question_images/#{ques_id}/"
    FileUtils.mkdir_p(dir_path)
    Dir["#{master_dir}/**/**/*"].each do |img|
      index = image_names.index(File.basename(img).split('.')[0].downcase)

      if index.present?
        img_name = (ques_images[index]).split('.')[0] + ".jpg"
        image = Magick::Image.read(img).first
        image.write(dir_path+img_name)
      end

    end
  end

  def create_group_question(user_id, group_ques,publisher_question_bank_id, hidden=false)
    question = Question.new
    question.publisher_question_bank_ids = [publisher_question_bank_id]
    question.question_text = group_ques.xpath("instruction").inner_text
    question.qtype = 'PassageQuestion'
    question.createdby = user_id
    question.default_mark = 0
    question.hidden = hidden
    question.save(:validate => false)

    group_ques.xpath("itags/itag").each do |tag|
      name = tag.attr("name").to_s
      value = tag.attr("value").to_s
      if ["course", "academic_class", "subject", "chapter", "concept_names"].include? name
        question.add_tag(name, value).tag_id
      else
        if name == "subjective_lines"
          question.answer_lines = value
          question.save(:validate => false)
        else
          question.add_tag(name, value)
        end
      end
    end

    child_questions = []
    group_ques.xpath("question_set").each do |ques|
      q = get_simple_question_hash(user_id, ques, publisher_question_bank_id)
      child_questions << q
    end

    question.attributes = {questions_attributes: child_questions}
    return question
  end

  def get_simple_question_hash(user_id, ques, publisher_question_bank_id)
    data = {}
    data['publisher_question_bank_ids'] = [publisher_question_bank_id]
    data['question_text'] = ques.xpath("question/question_text").inner_text
    data['qtype'] = get_qtype(ques.xpath("qtype").attr("value").to_s.downcase)
    data['default_mark'] = ques.xpath("score").attr("value").to_s.to_i rescue 1
    data['penalty'] = ques.xpath("penalty").attr("value").to_s.to_i rescue 0
    data['general_feedback'] = ques.xpath("question/solution")[0].inner_text rescue ''
    data['created_by'] = user_id
    data['actual_answer'] = ques.xpath("question/actual_answer").inner_text rescue ''
    data['hint'] = ques.xpath("question/hint").inner_text rescue ''

    if ['SmcqQuestion', 'MmcqQuestion', 'TrueFalseQuestion'].include? data['qtype']
      data['question_answers_attributes'] = []
      fraction = ques.xpath("question/answer").attr("value").to_s.split(",") if !ques.xpath("question/answer").nil?
      ques.xpath("question/option").each_with_index do |option, index|
        data['question_answers_attributes'] << get_question_answer_hash(fraction, index, option)
      end
    elsif ['FibQuestion'].include? data['qtype']
      data['question_fill_blanks_attributes'] = []
      ques.xpath("question/options_fib").each do |option|
        data['question_fill_blanks_attributes'] << get_question_fill_blank_hash(option)
      end
    end

    data['tag_ids'] = []
    ques.xpath("itags/itag").each do |tag|
      name = tag.attr("name").to_s
      value = tag.attr("value").to_s
      if ["course", "academic_class", "subject", "chapter", "concept_names"].include? name
        data['tag_ids'] << Question.get_tag_guid(name, value)
      else
        if name == "subjective_lines" && (['SubjectiveQuestion'].include? data['qtype'])
          data['answer_lines'] = value
        else
          data['tag_ids'] << Question.get_tag_guid(name, value)
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
    data1['answer'] = option.xpath("option_text").inner_text
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
    data['answer'] = ''
    c = 1
    option.xpath("option_blank").each do |option_blank|
      data['answer'] = option_blank.inner_text if c == 1
      data['answer'] = data['answer'] + "," + option_blank.inner_text
      c = c+1
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
    elsif qtype == "tof"
      "TrueFalseQuestion"
    elsif qtype == "saq" || qtype == "laq" || qtype == "vsaq"
      "SubjectiveQuestion"
    end
  end
end