class ZipUpload
  include Mongoid::Document

  def self.process_etx(etx_file="/home/inayath/Downloads/assessment_zip_upload_etxs/Maths-F2-C9-1-MCQ-EN/Maths-F2-C9-1-MCQ-EN.etx", cur_user=1, publisher_question_bank_id=(PublisherQuestionBank.first._id), hidden=false)
    center_id = "nil"
    folder_name = etx_file.split("/").last.split(".").first + "_files"
    publisher_question_bank = PublisherQuestionBank.find(publisher_question_bank_id)
    file = File.open(etx_file)
    etx = Nokogiri::XML(file)
    test_paper = etx.xpath("/ignitor_questions")
    question_ids = []

    test_paper.xpath("group_questions").each do |group_ques|
      question = ZipUpload.create_group_question(cur_user, group_ques,publisher_question_bank_id, hidden)
      question_ids << question._id
    end

    test_paper.xpath("question_set1").first(1).each do |ques|
      question = ZipUpload.create_simple_question(cur_user, ques,publisher_question_bank_id, folder_name)
      question_ids << question._id
    end
    publisher_question_bank.attributes = {question_ids:(publisher_question_bank.question_ids + question_ids)}
    publisher_question_bank.save!
    puts ("Successfully updated #{question_ids.count} -- #{question_ids}")
  end

  def self.create_simple_question(cur_user, ques,publisher_question_bank_id, folder_name)
    question_data = ZipUpload.get_simple_question_hash(cur_user,ques, publisher_question_bank_id)
    question = Question.create_question(question_data)
    question.update_attributes(question_text:ZipUpload.update_image_path(question.question_text, question._id,folder_name))
    return question
  end

  def self.update_image_path(text, ques_id,folder_name)
    if text.present?
      text.gsub(folder_name, "question_images/"+ques_id)
    else
      ''
    end
  end

  def self.copy_question_images(ques_id)
    ques_images = []
    question = Question.find(ques_id)
    Nokogiri::HTML(question.question_text).css('img').map{ |i| i['src'] }.each do |img|
      ques_images << img.split("/").last
    end

    Nokogiri::HTML(question.general_feedback).css('img').map{ |i| i['src'] }.each do |img|
      ques_images << img.split("/").last
    end

    question.question_answers.each do |qa|
      Nokogiri::HTML(qa.answer).css('img').map{ |i| i['src'] }.each do |img|
        ques_images << img.split("/").last
      end
    end

    if question.qtype == 'Passage'
      question.questions.each do |q|
        ZipUpload.copy_question_images(q._id)
      end
    end

    ques_images = ques_images.uniq
    dir_path = Rails.root.to_s + "/public/question_images/#{ques_id}/"
    parent_dir_path = Rails.root.to_s + "/public/aakash_qb_data"

    FileUtils.mkdir_p(dir_path)
    Dir["#{parent_dir_path}/**/**/**/images/*"].each do |img|
      index = ques_images.map{|n| n.downcase.split('.')[0]}.index(File.basename(img).split('.')[0].downcase)
      if index.present?
        img_name = (ques_images[index]).split('.')[0] + ".jpg"
        image = Magick::Image.read(img).first
        image.write(dir_path+img_name)
      end
    end
  end

  def self.create_group_question(cur_user, group_ques,publisher_question_bank_id, hidden=false)
    question = Question.new
    question.publisher_question_bank_ids = [publisher_question_bank_id]
    question.question_text = group_ques.xpath("instruction").inner_text
    question.qtype = 'PassageQuestion'
    question.createdby = cur_user.id rescue 1
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
      q = ZipUpload.get_simple_question_hash(cur_user, ques, publisher_question_bank_id)
      child_questions << q
    end

    question.attributes = {questions_attributes: child_questions}
    return question
  end

  def self.get_simple_question_hash(cur_user, ques, publisher_question_bank_id)
    data = {}
    data['publisher_question_bank_ids'] = [publisher_question_bank_id]
    data['question_text'] = ques.xpath("question/question_text").inner_text
    data['qtype'] = ZipUpload.get_qtype(ques.xpath("qtype").attr("value").to_s.downcase)
    data['default_mark'] = ques.xpath("score").attr("value").to_s.to_i rescue 1
    data['penalty'] = ques.xpath("penalty").attr("value").to_s.to_i rescue 0
    data['general_feedback'] = ques.xpath("question/solution")[0].inner_text
    data['created_by'] = cur_user.id rescue 1
    data['actual_answer'] = ques.xpath("question/actual_answer").inner_text rescue ''
    data['hint'] = ques.xpath("question/hint").inner_text rescue ''

    if ['SmcqQuestion', 'MmcqQuestion', 'TrueFalseQuestion'].include? data['qtype']
      data['question_answers_attributes'] = []
      fraction = ques.xpath("question/answer").attr("value").to_s.split(",") if !ques.xpath("question/answer").nil?
      ques.xpath("question/option").each_with_index do |option, index|
        data['question_answers_attributes'] << ZipUpload.get_question_answer_hash(fraction, index, option)
      end
    elsif ['FibQuestion'].include? data['qtype']
      data['question_fill_blanks_attributes'] = []
      ques.xpath("question/options_fib").each do |option|
        data['question_fill_blanks_attributes'] << ZipUpload.get_question_fill_blank_hash(option)
      end
    end

    data['tag_ids'] = []
    ques.xpath("itags/itag").each do |tag|
      name = tag.attr("name").to_s
      value = tag.attr("value").to_s
      if ["course", "academic_class", "subject", "chapter", "concept_names"].include? name
        tag = Tag.find_or_create_by(name: name, value: value, tags_db_id: TagsDb.first._id)
        data['tag_ids'] << tag._id
      else
        if name == "subjective_lines" && (['SubjectiveQuestion'].include? data['qtype'])
          data['answer_lines'] = value
        else
          tag = Tag.find_or_create_by(name: name, value: value, tags_db_id: TagsDb.first._id)
          data['tag_ids'] << tag._id
        end
      end
    end
    return data
  end

  def self.get_question_answer_hash(fraction, index, option)
    data1 = {}
    is_correct_option = 0
    if fraction.length == 1
      is_correct_option = ZipUpload.option_is_correct?(index, fraction.first) ? 1 : 0
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

  def self.option_is_correct?(index,fraction)
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

  def self.get_question_fill_blank_hash(option)
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

  def self.get_qtype(qtype)
    if qtype == "mcq"
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
