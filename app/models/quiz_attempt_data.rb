class QuizAttemptData
  include Mongoid::Document
  include Mongoid::Timestamps
  field :data, type: BSON::Binary
  field :user_id, type: String

  index({:user_id=>1})
  index({'data.asset_download_id' => 1,:user_id=>1})
  index({'data.asset_download_id' => 1,:user_id=>1,'data.player_subtype'=>1})
  index({'data.asset_guid' =>1,:user_id=>1})
  index({'data.book_id' =>1, :user_id=>1})
  index({'data.book_id' => 1,:user_id=>1,'data.player_subtype'=>1})

  after_create :process_quiz_attempt_data

  def process_quiz_attempt_data
    QuizAttemptDataJob.set(wait: 2.minutes).perform_later(self.id.to_s)
  end

  def process_quiz_attempt_data_delayed_job
    # failed_ids = []
    # QuizAttemptData.all.each do |qad|
    #   begin
    #     qad.process_quiz_attempt_data
    #   rescue
    #     failed_ids << qad.id
    #   end
    # end
    qad = self
    if ['jee_mains'].include? qad.data['player_subtype'] #[15664,19040].include? qad.user_id.to_i
      data = qad.data
      quiz = Quiz.where(guid:data['asset_download_id'])[0]
      if !quiz.present?
        quiz = Quiz.find(data['asset_download_id'])
      end
      quiz_json = quiz.quiz_json
      quiz_json_questions = quiz_json['questions']
      question_attempts_attributes = []
      quiz_section_attempts_attributes = []

      data['timeline'].each do |q_data|
        d = {}
        d['question_id'] = q_data['question_id']
        d['question_json'] = quiz_json_questions.select {|q| q["id"] == q_data['question_id']}[0]
        d['start_time'] = q_data['sessions'].first['start_time'].to_time.to_i
        d['end_time'] = q_data['sessions'].last['end_time'].to_time.to_i
        d['time_taken'] = q_data['sessions'].map{|s| (s['end_time'].to_time.to_i - s['start_time'].to_time.to_i)}.sum
        d['correct'] = data['correct'].include? q_data['question_id']
        if data['attempted'].include? q_data['question_id']
          d['marks_scored'] = (d['correct'] == true)? d['question_json']['marks']: d['question_json']['penalty']
          d['attempt_type'] = 'attempted'
        elsif data['unattempted'].include? q_data['question_id']
          d['marks_scored'] = 0
          d['attempt_type'] = 'un_attempted'
        elsif data['skipped_questions'].include? q_data['question_id']
          d['marks_scored'] = 0
          d['attempt_type'] = 'skipped'
        end

        if ['SmcqQuestion', 'MmcqQuestion'].include? d['question_json']['question_type']
          options = d['question_json']['options']
          attempted_answer_ids = q_data['sessions'].last['attempted_answer']
          question_answer_attempts_attributes = []

          options.each do |option|
            d1 = {}
            d1['question_answer_json'] = option
            d1['is_selected'] = (attempted_answer_ids.include? option['id']) ? true : false
            d1['is_correct'] = (option['fraction'] == true && d1['is_selected'] == true)? true : false

            question_answer_attempts_attributes << d1
          end
          d['question_answer_attempts_attributes'] = question_answer_attempts_attributes
        elsif ['FibQuestion'].include? d['question_json']['question_type']
          question_fill_blank_attempts_attributes = []
          ##########Write code here


          ###########
          d['question_fill_blank_attempts_attributes'] = question_fill_blank_attempts_attributes
        end
        question_attempts_attributes << d
      end

      #data for non attempted questions
      (quiz_json['questions'].map{|d| d['id']} - question_attempts_attributes.map{|d| d['question_id']}).each do |question_id|
        d = {}
        d['question_id'] = question_id
        d['question_json'] = quiz_json_questions.select {|q| q["id"] == question_id}[0]
        d['start_time'] = 0
        d['end_time'] = 0
        d['time_taken'] = 0
        d['correct'] = false
        d['marks_scored'] = 0
        if data['attempted'].include? question_id
          d['attempt_type'] = 'attempted'
        elsif data['unattempted'].include? question_id
          d['attempt_type'] = 'un_attempted'
        elsif data['skipped_questions'].include? question_id
          d['attempt_type'] = 'skipped'
        end

        if ['SmcqQuestion', 'MmcqQuestion'].include? d['question_json']['question_type']
          options = d['question_json']['options']
          attempted_answer_ids = []
          question_answer_attempts_attributes = []

          options.each do |option|
            d1 = {}
            d1['question_answer_json'] = option
            d1['is_selected'] = (attempted_answer_ids.include? option['id']) ? true : false
            d1['is_correct'] = (option['fraction'] == true && d1['is_selected'] == true)? true : false

            question_answer_attempts_attributes << d1
          end
          d['question_answer_attempts_attributes'] = question_answer_attempts_attributes
        elsif ['FibQuestion'].include? d['question_json']['question_type']
          question_fill_blank_attempts_attributes = []
          ##########Write code here


          ###########
          d['question_fill_blank_attempts_attributes'] = question_fill_blank_attempts_attributes
        end
        question_attempts_attributes << d
      end

      #quiz_sections_data
      if quiz_json['quiz_sections'].present?
        question_attempts_attributes_with_sections_data = []

        quiz_json['quiz_sections'].each do |quiz_section_data|
          quiz_section_questions_data = question_attempts_attributes.select{|d| quiz_section_data['question_ids'].include? d['question_json']['id']}

          d1 = {}
          d1['quiz_section_id'] = quiz_section_data['id']
          d1['quiz_section_name'] = quiz_section_data['name']
          d1['question_ids'] = quiz_section_data['question_ids']
          d1['marks_scored'] = quiz_section_questions_data.map{|d| d['marks_scored']}.sum rescue 0
          d1['total_marks'] = quiz_section_questions_data.map{|d| d['question_json']['marks']}.sum rescue 0
          d1['active_duration'] = quiz_section_questions_data.map{|d| d['time_taken']}.sum rescue 0

          d1['total'] = quiz_section_questions_data.count
          d1['attempted'] = quiz_section_questions_data.select{|d| d['attempt_type'] == 'attempted'}.count
          d1['un_attempted'] = quiz_section_questions_data.select{|d| d['attempt_type'] == 'un_attempted'}.count
          d1['correct'] = quiz_section_questions_data.select{|d| d['correct'] == true}.count
          d1['in_correct'] = d1['attempted'] - d1['correct']
          d1['skipped'] = quiz_section_questions_data.select{|d| d['attempt_type'] == 'skipped'}.count

          quiz_section_attempts_attributes << d1

          quiz_section_questions_data.each do |d|
            question_attempts_attributes_with_sections_data << d.merge(quiz_section_id:d1['quiz_section_id'],quiz_section_name:d1['quiz_section_name'])
          end
        end
      else
        question_attempts_attributes_with_sections_data = question_attempts_attributes
      end

      data['active_duration'] = question_attempts_attributes_with_sections_data.map{|d| d['time_taken']}.sum
      data['marks_scored'] = question_attempts_attributes_with_sections_data.map{|d| d['marks_scored']}.sum
      if data['published_id'].present?
        attempt_no = (QuizAttempt.where(user_id:qad.user_id.to_i,quiz_guid:quiz.guid).count + 1)
      else
        attempt_no = (QuizAttempt.where(user_id:qad.user_id.to_i,published_id:data['published_id']).count + 1)
      end

      total_count = question_attempts_attributes_with_sections_data.count
      attempted_count = question_attempts_attributes_with_sections_data.select{|d| d['attempt_type'] == 'attempted'}.count
      un_attempted_count = question_attempts_attributes_with_sections_data.select{|d| d['attempt_type'] == 'un_attempted'}.count
      correct_count = question_attempts_attributes_with_sections_data.select{|d| d['correct'] == true}.count
      in_correct_count = attempted_count - correct_count
      skipped_count = question_attempts_attributes_with_sections_data.select{|d| d['attempt_type'] == 'skipped'}.count

      if data['published_id'].present?
        group_ids = QuizTargetedGroup.find(data['published_id']).group_ids
        if group_ids.count == 1
          group_id = group_ids[0]
        else
          group_ids.each do |id|
            if UserManagementServer.get_students_in_group(id,'').map{|a| a['id']}.include? qad.user_id.to_i
              group_id = id
              break
            end
          end
        end
      end

      quiz_attempt_data = {quiz_attempt_data_id:qad.id.to_s,published_id:data['published_id'], user_id:qad.user_id.to_i,group_id:(group_id rescue 0),book_guid:data['book_id'],quiz_guid:quiz.guid,attempt_no:attempt_no,marks_scored:data['marks_scored'], total_marks:quiz.total_marks,start_time:data['start_time'].to_time.to_i,end_time:data['end_time'].to_time.to_i,active_duration:data['active_duration'],question_attempts_attributes:question_attempts_attributes_with_sections_data,quiz_section_attempts_attributes:quiz_section_attempts_attributes, total:total_count,attempted:attempted_count,un_attempted:un_attempted_count,correct:correct_count,in_correct:in_correct_count,skipped:skipped_count}
      QuizAttempt.create(quiz_attempt_data)
    end
  end

  def get_assessment_leader_board(user_id,assessment)

    sort_stage = {
        "$sort" => { "score" => -1 }
    }

    match_stage = {
        "$match" => {
            "$and"=> [{ "data.asset_download_id" => assessment}
            ]
        }
    }

    group_stage = {
        "$group" => {
            "_id" => {
                "user_id" => "$user_id"
            },
            "score"=> {"$max"=>'$data.score'}
        }
    }
    disk_stage = {
        "allow_disk_use"=> true
    }

    project_stage = {
        "$project" => { "user_id"=> 1, "data.score"=>1}
    }

    limit_stage = {
        "$limit" => 10
    }


    result = QuizAttemptData.collection.aggregate([match_stage,project_stage,group_stage,sort_stage,limit_stage],disk_stage)

    JSON.load(result.to_json)
  end

  def self.get_user_attempt_analytics(assessment,user_id)
    quiz = Quiz.where(:guid=>assessment).last
    sort_stage = {
        "$sort" => { "score" => -1 }
    }

    user_match_stage = {
        "$match" => {
            "$and"=> [{ "data.asset_download_id" => assessment},
                      {"user_id"=>user_id.to_s}
            ]
        }
    }

    topper_match_stage = {
        "$match" => {
            "$and"=> [{ "data.asset_download_id" => assessment}
            ]
        }
    }

    group_stage = {
        "$group" => {
            "_id" => {
                "user_id" => "$user_id"
            },
            "score"=> {"$max"=>'$data.score'},
            "attempted"=>{'$sum'=>{"$size"=>"$data.attempted"}},
            "correct"=>{'$sum'=>{"$size"=>"$data.correct"}},
            "incorrect"=>{'$sum'=>{"$size"=>"$data.incorrect"}},
            "active_duration"=>{"$max"=>"$data.active_duration"}

        }
    }


    avg_group_stage = {
        "$group" => {
            "_id" => {
                "assessment" => "$data.asset_download_id"
            },
            "score"=> {"$avg"=>'$data.score'},
            "attempted"=>{'$avg'=>{"$size"=>"$data.attempted"}},
            "correct"=>{'$avg'=>{"$size"=>"$data.correct"}},
            "incorrect"=>{'$avg'=>{"$size"=>"$data.incorrect"}},
            "active_duration"=>{"$avg"=>"$data.active_duration"}

        }
    }

    project_stage = {
        "$project" => { "user_id"=> 1,"score"=>1,
                        "attempted"=>1,
                        "correct"=>1,
                        "incorrect"=>1,
                        "active_duration"=>1,
                        "accuracy"=>{"$divide"=>["$correct","$attempted"]}

        }
    }

    disk_stage = {
        "allow_disk_use"=> true
    }

    limit_stage = {
        "$limit" => 1
    }

    result = {}

    begin
      user_result = QuizAttemptData.collection.aggregate([user_match_stage,group_stage,project_stage,sort_stage,limit_stage],disk_stage)

      user_data = JSON.load(user_result.to_json)
    rescue
      user_data = []
    end

    begin
      topper_result = QuizAttemptData.collection.aggregate([topper_match_stage,group_stage,project_stage,sort_stage,limit_stage],disk_stage)
      topper_data =  JSON.load(topper_result.to_json)
    rescue
      topper_data = []
    end

    begin
      avg_result = QuizAttemptData.collection.aggregate([topper_match_stage,avg_group_stage,project_stage,sort_stage],disk_stage)

      avg_data =  JSON.load(avg_result.to_json)

    rescue
      avg_data = []
    end
    #sections = QuizSection.where(:id.in=>quiz.quiz_section_ids).map{|i| i.as_json[:name]}


    result["user"] = user_data.last
    result["topper"] = topper_data.last
    result["assessment_avg"] = avg_data.last
    return result

  end

  def self.get_user_attempt_analytics_v1(assessment,user_id)
    @source = File.read(Rails.root.join("app/assets/javascripts/rank_array.js"))
    @context = ExecJS.compile(@source)
    marks = {}
    @quiz = Quiz.where(:guid=>assessment).last
    quiz_attempt = QuizAttempt.where(:quiz_guid=>assessment,:user_id=>user_id).last
    if quiz_attempt.present?
      marks[:total_questions] = @quiz.total_questions
      marks[:total_time] = @quiz.total_time
      marks[:total_score] = @quiz.total_marks
      marks[:accuracy] = (quiz_attempt.correct.to_f/quiz_attempt.total.to_f).round(2)
      marks[:attempt_rate] = (quiz_attempt.attempted.to_f/quiz_attempt.active_duration.to_f).round(2)
      marks[:time] = quiz_attempt.active_duration
      marks[:marks_scored] = quiz_attempt.marks_scored
      marks[:correct] = quiz_attempt.correct
      marks[:in_correct] = quiz_attempt.in_correct
      marks[:un_attempted] = quiz_attempt.un_attempted
      marks[:rank] = get_user_quiz_attempt_rank(assessment,user_id,quiz_attempt.quiz_attempt_data_id)
      min_max_average = get_quiz_max_min_details(assessment,user_id)

      marks[:min_marks] = min_max_average["min_marks"]
      marks[:max_marks] = min_max_average["max_marks"]
      marks[:avg_marks] = min_max_average["avg_score"]

      quiz_section_details = get_quiz_section_details(assessment,user_id)
      marks[:quiz_section_details] = quiz_section_details
      quiz_section_data = get_quiz_section_data(assessment,user_id,quiz_attempt.quiz_attempt_data_id)
      marks[:quiz_section_data] = quiz_section_data
    end
    return marks
  end


  def self.get_user_quiz_attempt_topic_details(assessment,user_id)
    topic_data = {}
    @quiz = Quiz.where(:guid=>assessment).last
    topic_details = @quiz.topic_details
    quiz_attempt = QuizAttempt.where(:quiz_guid=>assessment,:user_id=>user_id).last

    data = QuizAttempt.collection.aggregate([{"$project"=>{"user_id"=>1,"quiz_guid"=>1,"quiz_section_attempts"=>1,"quiz_attempt_data_id"=>1,"question_attempts"=>1}},
                                             {"$match"=>{"$and"=>[{"quiz_guid"=>assessment},{"user_id"=>user_id},{"quiz_attempt_data_id"=>quiz_attempt.quiz_attempt_data_id}]}},
                                             {"$group"=>{"_id"=>{"user_id"=>"$user_id","quiz_attempt_data_id"=>"$quiz_attempt_data_id","marks_scored"=>"$question_attempts.marks_scored",
                                                                 "assessment_id"=>"$quiz_guid","question"=>"$question_attempts.question_json.id","corrects"=>"$question_attempts.correct"}}},
                                             {"$project"=>{"user_id"=>"$_id.user_id","quiz_attempt_data_id"=>"$_id.quiz_attempt_data_id","marks_scored"=>"$_id.marks_scored",
                                                           "assessment_id"=>"$_id.assessment_id","question_id"=>"$_id.question","corrects"=>"$_id.corrects","_id"=>0}}
                                            ],"allow_disk_use"=> true)

    data = JSON.load(data.to_json)[0]
    keys = data["question_id"]
    corrects = data["corrects"]
    marks = data["marks_scored"]
    vals = corrects.zip(marks)
    question_hash = Hash[keys.zip(vals)]
    topic_details["sections"].each do |sec|
      topic_data[sec["name"]] = []
      sec["topics"].each do |topic|
        topic[topic["name"]] = {}
        topic[topic["name"]]["total_marks"] = topic["total_marks"]
        topic[topic["name"]]["total_questions"] = topic["total_questions"]
        marks = 0
        topic["question_ids"].each do |qid|
          marks = marks+question_hash[qid][1]
        end
        topic[topic["name"]]["marks_scored"] = marks
        topic_data[sec["name"]] << {topic["name"]=>topic[topic["name"]]}
      end
    end

    result = []
    topic_data.keys.each do |k|
      topic_details = []
      topic_data[k].each do |t|
        topic_details << {"name"=>t.keys.last}.merge!(t[t.keys.last])
      end
      result << {"name" => k, "topic_details" => topic_details }
    end

    return result
  end


  def self.get_quiz_question_attempts(assessment,user_id)
    @quiz = Quiz.where(:guid=>assessment).last
    topic_details = @quiz.topic_details
    quiz_attempt = QuizAttempt.where(:quiz_guid=>assessment,:user_id=>user_id).last
    sections_data = {}
    QuizSection.where(:id.in=>@quiz.quiz_section_ids).map{|i| sections_data.merge!({i.id.to_s=>i.name})}
    data= {}
    data["sections"] = []
    topic_details["sections"].each do |sec|
      data["sections"] << {"name"=>sec["name"],"total_questions"=>sec["total_questions"]}
    end
    data["total_topics"] = topic_details["sections"].map{|i|i["topics"].count}.sum
    data["correct"] = quiz_attempt.correct
    data["in_correct"] = quiz_attempt.in_correct
    data["un_attempted"] = quiz_attempt.un_attempted
    data["questions"] = []
    #@quiz.all_question_ids.each do |q_id|
    #quiz_attempt.question_attempts.where("question_id"=>q_id,"attempt_type"=>"attempted").each do |qa|
    quiz_attempt.question_attempts.each do |qa|
      selected_options = qa.question_answer_attempts.select{|a| a.is_selected == true}.map{|b| b.question_answer_json['id']} rescue []
      correct_options = qa.question_json['answers'].flatten rescue []
      data["questions"] << {"question_id"=>qa.question_id,'selected_options'=>selected_options,'correct_options'=>correct_options,"correct"=>qa.correct,"start_time"=>qa.start_time,"end_time"=>qa.end_time,"section_name"=>sections_data[qa.quiz_section_id]}
    end
    #end

    return data
  end

  def self.get_given_quiz_analytics(assessments,user_id)
    data = []
    assessments.each do |assessment|
      quiz = Quiz.where(:guid=>assessment)
      attempt = QuizAttempt.where(:quiz_guid=>assessment).last
      data <<  {"name"=>quiz.name,"score"=>attempt.marks_scored,"date"=>Time.at(attempt.end_time),"rank"=>get_user_quiz_attempt_rank(assessment,user_id,attempt.quiz_attempt_data_id),
                "subject_data" => get_quiz_section_data(assessment,user_id,attempt.quiz_attempt_data_id).map{|i| {"sub"=>i["sub"],"rank"=>i["rank"],"marks"=>i["marks"],"total_questions"=>i["total_questions"]}}}
    end
    return data
  end


  def self.get_given_quiz_topic_analytics(assessments,user_id)
    data = []
    result = {}
    assessments.each do |assessment|
      quiz = Quiz.where(:guid=>assessment)
      attempt = QuizAttempt.where(:quiz_guid=>assessment).last
      data << QuizAttemptData.get_user_quiz_attempt_topic_details(assessment,user_id)
    end

    data = data.flatten
    # tmp_array = []
    # data.each do |d|
    #   d.keys.each do |sub|
    #     d[sub].each do |tp|
    #       if tmp_array.include? (sub+"_"+tp.keys[0]).to_s
    #         result[tp.keys[0]]["count"] = result[tp.keys[0]]["count"].to_i+1
    #         result[tp.keys[0]]["total_marks"] = result[tp.keys[0]]["total_marks"].to_f+tp[tp.keys[0]]["total_marks"].to_f
    #         result[tp.keys[0]]["total_questions"] = result[tp.keys[0]]["total_questions"].to_i+tp[tp.keys[0]]["total_questions"].to_i
    #         result[tp.keys[0]]["marks_scored"] = result[tp.keys[0]]["marks_scored"].to_f+tp[tp.keys[0]]["marks_scored"].to_f
    #       else
    #         tmp_array << (sub+"_"+tp.keys[0]).to_s
    #         result = result.merge({tp.keys[0]=>(tp[tp.keys[0]].merge({"count"=>1,"subject"=>sub}))})
    #       end
    #     end
    #   end
    # end
    return data
  end

  def self.get_user_quiz_attempt_rank(assessment,user_id,attempt_id)
    @source = File.read(Rails.root.join("app/assets/javascripts/rank_array.js"))
    @context = ExecJS.compile(@source)
    data = QuizAttempt.collection.aggregate([{"$project"=>{"user_id"=>1,"marks_scored"=>1,"quiz_guid"=>1,"quiz_attempt_data_id"=>1}},
                                             {"$match"=>{"quiz_guid"=>assessment}},
                                             {"$sort"=>{"marks_scored"=>-1}},
                                             {"$group"=>{"_id"=>false, "users"=>{"$push"=>{"_id"=>"$_id","user_id"=>"$user_id","quiz"=>"$quiz_guid","marks_scored"=>"$marks_scored","quiz_attempt_data_id"=>"$quiz_attempt_data_id"}}}},
                                             {"$addFields"=>{"users"=>@context.call("rankArray","$users","marks_scored","dense=false")}},
                                             {"$unwind"=>{"path"=> "$users"}},
                                             {"$project"=>{"user"=>"$users.user_id","rank"=>"$users.rank","_id"=>0,"quiz_attempt_data_id"=>"$users.quiz_attempt_data_id"}},
                                             {"$match"=>{"$and"=>[{"user"=>user_id},{"quiz_attempt_data_id"=>attempt_id}]}}],"allow_disk_use"=> true)

    return JSON.load(data.to_json)[0]["rank"]

  end


  def self.get_quiz_max_min_details(assessment,user_id)
    data =  QuizAttempt.collection.aggregate([{"$project"=>{"user_id"=>1,"quiz_guid"=>1,"marks_scored"=>1}},
                                              {"$match"=>{"quiz_guid"=>assessment}},
                                              {"$group"=>{"_id"=>{"assessment_id"=>"$quiz_guid"},"min_marks"=>{"$min"=>"$marks_scored"},"max_marks"=>{"$max"=>"$marks_scored"},"avg_score"=>{"$avg"=>"$marks_scored"},}},
                                              {"$project"=>{"max_marks"=>"$max_marks","min_marks"=>"$min_marks","avg_score"=>"$avg_score","_id"=>0}}],"allow_disk_use"=> true)


    return JSON.load(data.to_json)[0]

  end


  def self.get_quiz_section_details(assessment,user_id)
    data = QuizAttempt.collection.aggregate([
                                                {"$unwind"=>"$quiz_section_attempts"},
                                                {"$project"=>{"quiz_section_attempts"=>1, "user_id"=>1,"quiz_guid"=>1,"marks_scored"=>1}},
                                                {"$match"=>{"quiz_guid"=>assessment}},
                                                {"$match"=>{"user_id"=>user_id}},

                                                {"$group"=>{"_id"=>{"assessment_id"=>"$quiz_guid","user_id"=>"$user_id","sub"=>"$quiz_section_attempts.quiz_section_name","total"=>"$quiz_section_attempts.total"},
                                                            "min_marks"=>{"$min"=>"$quiz_section_attempts.marks_scored"},"max_marks"=>{"$max"=>"$quiz_section_attempts.marks_scored"}, "avg_score"=>{"$avg"=>"$quiz_section_attempts.marks_scored"}}},
                                                {"$project"=>{"subject"=>"$_id.sub","max_marks"=>"$max_marks","min_marks"=>"$min_marks","avg_score"=>"$avg_score","_id"=>0,"total_questions"=>"$_id.total"}},
                                                {"$sort"=>{"subject"=>-1}}],"allow_disk_use"=> true)
    return JSON.load(data.to_json)
  end


  def self.get_quiz_section_data(assessment,user_id,attempt_id)
    @source = File.read(Rails.root.join("app/assets/javascripts/rank_array.js"))
    @context = ExecJS.compile(@source)
    section_data = []
    @quiz = Quiz.where(:guid=>assessment).last
    @quiz.quiz_section_ids.each do |section_id|

      data = QuizAttempt.collection.aggregate([{"$unwind"=>"$quiz_section_attempts"},
                                               {"$match"=>{"$and"=>[{"quiz_guid"=>assessment},{"quiz_section_attempts.quiz_section_id"=>section_id}]}},
                                               {"$project"=>{"user_id"=>1,"_id"=>0,"quiz_guid"=>1,"quiz_section_attempts"=>1,"quiz_attempt_data_id"=>1}}, {"$sort"=>{"quiz_section_attempts.marks_scored"=>-1}},
                                               {"$group"=>{"_id"=>false, "users"=>{"$push"=>{"_id"=>"$_id", "user_id"=>"$user_id","quiz"=>"$quiz_guid",
                                                                                             "sub"=>"$quiz_section_attempts.quiz_section_name","marks_scored"=>"$quiz_section_attempts.marks_scored",
                                                                                             "correct"=>"$quiz_section_attempts.correct",
                                                                                             "quiz_attempt_data_id"=>"$quiz_attempt_data_id",
                                                                                             "incorrect"=>"$quiz_section_attempts.in_correct","unattempted"=>"$quiz_section_attempts.un_attempted",
                                                                                             "skipped"=>"$quiz_section_attempts.skipped","total"=>"$quiz_section_attempts.total","active_duration"=>"$quiz_section_attempts.active_duration"}}}},
                                               {"$addFields"=>{"users"=>@context.call("rankArray","$users","marks_scored","dense=false")}},
                                               {"$unwind"=>{"path"=>"$users"}},
                                               {"$project"=>{"quiz_attempt_data_id"=>"$users.quiz_attempt_data_id","user"=>"$users.user_id",
                                                             "sub"=>"$users.sub","marks"=>"$users.marks_scored","rank"=>"$users.rank","correct"=>"$users.correct",
                                                             "incorrect"=>"$users.incorrect","unattempted"=>"$users.unattempted","skipped"=>"$users.skipped","total_questions"=>"$users.total",
                                                             "active_duration"=>"$users.active_duration","_id"=>0}},{"$match"=>{"$and"=>[{"user"=>user_id},{"quiz_attempt_data_id"=>attempt_id}]}},
                                               {"$sort"=>{"sub"=>-1}}],"allow_disk_use"=> true)

      section_data << JSON.load(data.to_json)[0]
    end
    return section_data
  end

  def self.get_group_assessment_analytics(assessment,publish_id,group)
    result = []
    data = {}
    @quiz = Quiz.where(:guid=>assessment).last
    data[:total_questions] = @quiz.total_questions
    data[:total_marks] = @quiz.total_marks
    data[:total_time] = @quiz.total_time
    @group_data = []
    @attempts = QuizAttempt.where(:quiz_guid=>assessment,:attempt_no=>1)
    data["max_score"] = @attempts.max(:marks_scored)
    data["avg_score"] = @attempts.avg(:marks_scored)
    @topper_attempt = @attempts.where(:marks_scored=>data["max_score"]).first
    topper_data = []
    @quiz.quiz_section_ids.each do |section_id|
      section_details = {}
      section_attempt = @topper_attempt.quiz_section_attempts.where(:quiz_section_id=>section_id).last
      section_details["name"] = section_attempt["quiz_section_name"]
      section_details["topper_score"] = section_attempt["marks_scored"]
      section_details["topper_attempt_rate"] = (section_attempt["attempted"]/section_attempt["total"].to_f).round(2)
      section_details["topper_accuracy"] = (section_attempt["correct"]/section_attempt["attempted"].to_f).round(2)
      section_details["topper_active_duration"] = section_attempt["active_duration"]
      section_details["time_per_question"] = @topper_attempt.question_attempts.where("question_id"=>{"$in"=>section_attempt["question_ids"]}).avg(:time_taken)
      topper_data << section_details
    end

    topper_data.reverse!

    @topper_attempt.quiz_section_attempts.each do |section|
    end


    section_data = []

    section_data =  QuizAttempt.collection.aggregate([{"$unwind"=>"$quiz_section_attempts"},
                                                      {"$match"=>{"$and"=>[{"quiz_guid"=>assessment},{"attempt_no"=>1}]}},
                                                      {"$group"=>{"_id"=>{"assessment_id"=>"$quiz_guid","sub"=>"$quiz_section_attempts.quiz_section_name","marks"=>"$total_marks","total_questions"=>"$quiz_section_attempts.total"},
                                                                  "avg_score"=>{"$avg"=>"$quiz_section_attempts.marks_scored"},"avg_corrects"=>{"$avg"=>"$quiz_section_attempts.correct"},"avg_attempted"=>{"$avg"=>"$quiz_section_attempts.attempted"},"avg_duration"=>{"$avg"=>"$quiz_section_attempts.active_duration"},
                                                      }},
                                                      {"$project"=>{"subject"=>"$_id.sub",
                                                                    "total"=>"$_id.marks",
                                                                    "avg_score"=>"$avg_score","_id"=>0,
                                                                    "avg_attempt_rate"=>{"$cond"=>[{"$eq"=>["$_id.total_questions",0]},0, {"$divide"=>["$avg_attempted","$_id.total_questions"]}]},
                                                                    "avg_accuracy"=>{"$cond"=>[{"$eq"=>["$avg_attempted",0.0]},0,{"$divide"=>["$avg_corrects","$avg_attempted"]}]},
                                                                    "average_duration"=>"$avg_duration"}}],"allow_disk_use"=> true)

    section_data = JSON.load(section_data.to_json)


    time_question_data = QuizAttempt.collection.aggregate([{"$unwind"=>"$question_attempts"},
                                                           {"$match"=>{"$and"=>[{"quiz_guid"=>assessment},{"attempt_no"=>1},{"question_attempts.attempt_type" => "attempted"},"question_attempts.question_id"=>{"$in"=>@quiz.all_question_ids}]}},
                                                           {"$group"=>{"_id"=>{"question"=>"$question_attempts.question_id","section_id"=>"$question_attempts.quiz_section_name",
                                                           },"avg"=>{"$avg"=>"$question_attempts.time_taken"}}},
                                                           {"$project"=>{"_id"=>0,"subject"=>"$_id.section_id","avg_time"=>"$avg"}},
                                                           {"$group"=>{"_id"=>{"subject"=>'$subject'},"avg"=>{"$avg"=>'$avg_time'}}},
                                                           {"$project"=>{"_id"=>0,"subject"=>"$_id.subject","avg"=>"$avg"}}
                                                          ],"allow_disk_use"=> true)

    time_question_data = JSON.load(time_question_data.to_json)

    section_combine_data = []
    section_data.each do |k|
      time_question_data.each do |j|
        if j["subject"] == k["subject"]
          k = k.merge({"avg_time_question"=>j["avg"]})
          section_combine_data << k
        end
      end
    end
    result << {"section_data"=>section_combine_data}
    result  << {"quiz_details"=>data}
    result << {"topper_data"=>topper_data}

    return result

  end

  def self.get_group_assessment_rank_data(assessment,publish_id,group_id)
    result = []
    @source = File.read(Rails.root.join("app/assets/javascripts/rank_array.js"))
    @context = ExecJS.compile(@source)
    section_data = []
    @quiz = Quiz.where(:guid=>assessment).last
    @quiz.quiz_section_ids.each do |section_id|

      data = QuizAttempt.collection.aggregate([{"$unwind"=>"$quiz_section_attempts"},
                                               {"$match"=>{"$and"=>[{"quiz_guid"=>assessment},{"attempt_no"=>1},{"quiz_section_attempts.quiz_section_id"=>section_id}]}},
                                               {"$project"=>{"user_id"=>1,"_id"=>0,"quiz_guid"=>1,"quiz_section_attempts"=>1,"quiz_attempt_data_id"=>1}}, {"$sort"=>{"quiz_section_attempts.marks_scored"=>-1}},
                                               {"$group"=>{"_id"=>false, "users"=>{"$push"=>{"_id"=>"$_id", "user_id"=>"$user_id","quiz"=>"$quiz_guid",
                                                                                             "sub"=>"$quiz_section_attempts.quiz_section_name","marks_scored"=>"$quiz_section_attempts.marks_scored",
                                                                                             "correct"=>"$quiz_section_attempts.correct",
                                                                                             "quiz_attempt_data_id"=>"$quiz_attempt_data_id",
                                                                                             "incorrect"=>"$quiz_section_attempts.in_correct","unattempted"=>"$quiz_section_attempts.un_attempted",
                                                                                             "attempted"=>"$quiz_section_attempts.attempted","total"=>"$quiz_section_attempts.total","active_duration"=>"$quiz_section_attempts.active_duration"}}}},
                                               {"$addFields"=>{"users"=>@context.call("rankArray","$users","marks_scored","dense=false")}},
                                               {"$unwind"=>{"path"=>"$users"}},
                                               {"$project"=>{"user"=>"$users.user_id",
                                                             "sub"=>"$users.sub","marks"=>"$users.marks_scored","rank"=>"$users.rank","correct"=>"$users.correct",
                                                             "incorrect"=>"$users.incorrect","unattempted"=>"$users.unattempted","attempted"=>"$users.attempted","total_questions"=>"$users.total",
                                                             "active_duration"=>"$users.active_duration","_id"=>0}}],"allow_disk_use"=> true)

      section_data << JSON.load(data.to_json)
    end
    ress = []
    users  = section_data.map{|i| i.map{|j|  j["user"]}}.flatten.uniq
    subjects = section_data.map{|i| i.map{|j|  j["sub"]}}.flatten.uniq
    users.each do |u|
      u_data = {}
      u_data[u] = []
      subjects.each do |s|
        section_data.each do |sd|
          sd.each do |d|
            if d["user"] == u && d["sub"] == s
              td = d
              td =  td.merge({"attempt_rate"=>((td["attempted"]/td["total_questions"].to_f).round(2) rescue 0)})
              td =  td.merge({"accuracy"=>((td["correct"]/td["attempted"].to_f).round(2) rescue 0)})
              td = td.merge({"speed"=>((td["attempted"]/td["active_duration"]).round(2) rescue 0)})
              u_data[u] << td
            end
          end
        end
      end
      ress << u_data
    end

    ud = {}
    user_data = QuizAttemptData.get_user_assesment_attempt_rank(assessment)
    user_data.each do |i|
      ud[i["user"]] = i
    end

    ress.each do |re|
      re.keys.each do |k|
        subject_details = []
        user_data = {"name"=>re.keys.last}.merge!({"subject_details"=>re[re.keys.last]})
        subject_details << user_data.merge({"total"=>ud[k]})
        result << subject_details
      end
    end

    sections = QuizSection.where(:id.in=>@quiz.quiz_section_ids).map{|i|i.quiz_section_language_specific_datas.last.name}.sort

    user_section_details = {}
    sections.each do |i|
      user_section_details[i] = []
      result.flatten.each do |re|
        re["subject_details"].each do |rsub|
          if  rsub["sub"] == i
            user_section_details[i] << rsub
          end
        end
      end
    end

    user_section_data = []
    user_section_details.keys.each do |k|
      user_section_data <<  {"name" => k,"users"=>user_section_details[k]}
    end

    user_total_data = []

    result.flatten.each do |re|
      user_total_data << re["total"]
    end

    return {:section_data=>user_section_data,:user_data=>user_total_data} #result.flatten
  end


  def self.get_group_assessment_subject_details(assessment,publish_id,group)
    user_data = QuizAttempt.collection.aggregate([
                                                     {"$match"=>{"$and"=>[{"quiz_guid"=>assessment},{"attempt_no"=>1}]}},
                                                     {"$group"=>{"_id"=>{"user"=>"$user_id","marks_scored"=>"$marks_scored","total"=>"$total"}}},
                                                     {"$project"=>{"user_id"=>"$_id.user","total_marks_scored"=>"$_id.marks_scored","_id"=>0,"total"=>"$_id.total",
                                                                   "avg"=>{"$cond"=>[{"$eq"=>["$_id.total",0]},0, "$multiply"=>[{"$divide"=>["$_id.marks_scored","$_id.total"]},100]]}}}
                                                 ],"allow_disk_use"=> true)

    user_data = JSON.load(user_data.to_json)
    user_sec_data = QuizAttempt.collection.aggregate([{"$unwind"=>"$quiz_section_attempts"},
                                                      {"$match"=>{"$and"=>[{"quiz_guid"=>assessment},{"attempt_no"=>1}]}},
                                                      {"$group"=>{"_id"=>{"user"=>"$user_id","marks_scored"=>"$quiz_section_attempts.marks_scored","sub"=>"$quiz_section_attempts.quiz_section_name","total"=>"$quiz_section_attempts.total"}}},
                                                      {"$project"=>{"user_id"=>"$_id.user","subject"=>"$_id.sub","marks_scored"=>"$_id.marks_scored","_id"=>0,"total"=>"$_id.total","avg"=>{"$cond"=>[{"$eq"=>["$_id.total",0]},0, "$multiply"=>[{"$divide"=>["$_id.marks_scored","$_id.total"]},100]]}}},
                                                      {"$sort"=>{"user_id"=>1}} ],"allow_disk_use"=> true)

    user_sec_data = JSON.load(user_sec_data.to_json)

    users = user_data.map{|i| {i["user_id"]=>i["total_marks_scored"]}}.inject(&:merge)
    users = {}
    user_data.each do |i|
      users[i["user_id"]] = i
    end

    ress = []
    users.keys.each do |k|
      uk = {}
      uk[k] = []
      user_sec_data.each do |ud|
        if ud["user_id"] == k
          uk[k] << ud
        end
        ress << uk
      end
    end

    result = []

    ress.uniq.each do |re|
      re.keys.each do |k|
        sub_details = []
        re[k].each do |i|
          i.delete("user_id")
          sub_details << i
        end
        result << {"user"=>k,"subject_details"=>sub_details,"total_marks_scored"=>users[k]}
      end
    end

    #return result


    range = 0..100
    r = range.each_slice(range.last/10).with_index.with_object({}) { |(a,i),h|h[a.first..a.last]=0 }
    sections  = QuizSection.where(:id.in=>Quiz.where(:guid=>assessment).last.quiz_section_ids).map{|i|i.quiz_section_language_specific_datas.last.name}.sort
    section_hash = Hash[sections.collect { |item| [item, (range.each_slice(range.last/10).with_index.with_object({}) { |(a,i),h|h[a.first..a.last]=0 })] } ]

    result.each do |re|
      r.keys.each do |k|
        if re["total_marks_scored"]["avg"].between?(k.first,k.last)
          r[k] = r[k]+1
        end
      end
    end


    result.each do |re|
      re["subject_details"].each do |sd|
        section_hash[sd["subject"]].keys.each do |sk|
          if sd["avg"].between?(sk.first,sk.last)
            section_hash[sd["subject"]][sk] = section_hash[sd["subject"]][sk]+1
            break
          end
        end
      end
    end

    data = {"total"=>r.values,"sections"=>section_hash.keys.map{|i|
      {"name"=>i, "values"=>section_hash[i].values }
    },:range =>10}
    return data
  end

  def self.get_assessment_group_topic_details(assessment,publish_id,group)
    topic_data = {}
    @quiz = Quiz.where(:guid=>assessment).last
    topic_details = @quiz.topic_details

    data = QuizAttempt.collection.aggregate([{"$project"=>{"user_id"=>1,'attempt_no'=>1,"quiz_guid"=>1,"quiz_section_attempts"=>1,"quiz_attempt_data_id"=>1,"question_attempts"=>1}},
                                             {"$match"=>{"$and"=>[{"quiz_guid"=>assessment},{"attempt_no"=>1}]}},
                                             {"$group"=>{"_id"=>{"user_id"=>"$user_id","quiz_attempt_data_id"=>"$quiz_attempt_data_id","marks_scored"=>"$question_attempts.marks_scored",
                                                                 "assessment_id"=>"$quiz_guid","question"=>"$question_attempts.question_json.id","corrects"=>"$question_attempts.correct"}}},
                                             {"$project"=>{"user_id"=>"$_id.user_id","quiz_attempt_data_id"=>"$_id.quiz_attempt_data_id","marks_scored"=>"$_id.marks_scored",
                                                           "assessment_id"=>"$_id.assessment_id","question_id"=>"$_id.question","corrects"=>"$_id.corrects","_id"=>0}}
                                            ],"allow_disk_use"=> true)

    data = JSON.load(data.to_json)[0]
    keys = data["question_id"]
    corrects = data["corrects"]
    marks = data["marks_scored"]
    vals = corrects.zip(marks)
    question_hash = Hash[keys.zip(vals)]
    topic_details["sections"].each do |sec|
      topic_data[sec["name"]] = []
      sec["topics"].each do |topic|
        topic[topic["name"]] = {}
        topic[topic["name"]]["total_marks"] = topic["total_marks"]
        topic[topic["name"]]["total_questions"] = topic["total_questions"]
        marks = 0
        topic["question_ids"].each do |qid|
          marks = marks+question_hash[qid][1]
        end
        topic[topic["name"]]["marks_scored"] = marks
        topic[topic["name"]]["avg_marks"] = (marks.to_f/topic["total_marks"]).round(2)
        topic_data[sec["name"]] << {topic["name"]=>topic[topic["name"]]}
      end
    end

    result = []
    topic_data.keys.each do |k|
      topic_details = []
      topic_data[k].each do |t|
        topic_details << {"name"=>t.keys.last}.merge!(t[t.keys.last])
      end
      result << {"name" => k, "topic_details" => topic_details }
    end


    return result

  end

  def self.get_user_assesment_attempt_rank(assessment)
    @source = File.read(Rails.root.join("app/assets/javascripts/rank_array.js"))
    @context = ExecJS.compile(@source)
    data = QuizAttempt.collection.aggregate([{"$match"=>{"$and"=>[{"quiz_guid"=>assessment},{"attempt_no"=>1}]}},
                                             {"$sort"=>{"marks_scored"=>-1}},
                                             {"$group"=>{"_id"=>false, "users"=>{"$push"=>{"_id"=>"$_id","user_id"=>"$user_id","quiz"=>"$quiz_guid","marks_scored"=>"$marks_scored","correct"=>"$correct","incorrect"=>"$in_correct", "attempted"=>"$attempted","un_attempted"=>"$un_attempted","total"=>"$total","duration"=>"$active_duration"}}}},
                                             {"$addFields"=>{"users"=>@context.call("rankArray","$users","marks_scored","dense=false")}},
                                             {"$unwind"=>{"path"=> "$users"}},
                                             {"$project"=>{"user"=>"$users.user_id","rank"=>"$users.rank","_id"=>0,"score"=>"$users.marks_scored","correct"=>"$users.correct","incorrect"=>"$users.incorrect", "attempted"=>"$users.attempted","un_attempted"=>"$users.un_attempted","total"=>"$users.total","duration"=>"$users.duration",
                                                           "attempt_rate"=>{"$cond"=>[{"$eq"=>["$users.total",0]},0, {"$divide"=>["$users.attempted","$users.total"]}]},
                                                           "accuracy"=>{"$cond"=>[{"$eq"=>["$users.attempted",0]},0, {"$divide"=>["$users.correct","$users.attempted"]}]},
                                                           "speed"=>{"$cond"=>[{"$eq"=>["$users.duration",0]},0, {"$divide"=>["$users.attempted","$users.duration"]}]}
                                             }},
                                            ],"allow_disk_use"=> true)

    return JSON.load(data.to_json)
  end



  def self.get_question_error_analytics(assessment,publish_id,group_id)
    data = QuizAttempt.collection.aggregate(
        [
            {"$unwind"=>'$question_attempts'},
            {"$match"=>{"$and"=>[{'quiz_guid'=>assessment},{'attempt_no'=>1}]}},

            {"$group"=>{"_id"=>{"user_id"=> '$user_id',"question"=>'$question_attempts.question_json.id',

                                "corrects"=>'$question_attempts.correct',"time"=>'$question_attempts.time_taken',"marks_scored"=>'$question_attempts.marks_scored',
                                "difficulty"=>'$question_attempts.question_json.tags.difficulty_level',
                                "attempt_type" => '$question_attempts.attempt_type', "type"=>'$question_attempts.question_json.tags.qsubtype',
                                "section"=>'$question_attempts.quiz_section_name', "con"=>'$question_attempts.question_json.tags.concept'}}},

            {"$project"=>{"user_id"=>'$_id.user_id',"section"=>'$_id.section',"concept"=>'$_id.con',"question_id"=>'$_id.question', "attempt_type"=>'$_id.attempt_type',
                          "corrects"=>'$_id.corrects',"_id"=>0,"time"=>'$_id.time', "question_type"=>'$_id.type',"difficulty"=>'$_id.difficulty'}},

            {"$group"=>{"_id"=>{"question_id"=>'$question_id',"sec"=>'$section',"con"=>'$concept',"qtype"=>'$question_type',
                                "difficulty"=>'$difficulty'}, "count"=> { "$sum"=> 1 }, "corrects"=> {"$push"=>{"correct"=>'$corrects',"attempt_type"=>'$attempt_type'}},
                        "avg_time"=>{"$avg"=>'$time'}}},

            {"$project"=>{"question_id"=>'$_id.question_id',"section"=>'$_id.sec',"concept"=>'$_id.con',"question_type"=>'$_id.qtype',"difficulty"=>'$_id.difficulty',
                          "avg_time"=>'$avg_time',"corrects"=>'$corrects.correct',"attempt_type"=>'$corrects.attempt_type',"count"=>'$count',"_id"=>0}},
            {"$unwind"=>'$difficulty'},{"$unwind"=>'$question_type'},{"$unwind"=>'$concept'},
        ],"allow_disk_use"=> true)

    data = JSON.load(data.to_json)

    range = 0..100
    sections  = QuizSection.where(:id.in=>Quiz.where(:guid=>assessment).last.quiz_section_ids).map{|i|i.quiz_section_language_specific_datas.last.name}.sort
    section_hash = Hash[sections.collect { |item| [item, (range.each_slice(range.last/5).with_index.with_object({}) { |(a,i),h|h[a.first..a.last]=[] })] } ]
    q_data = []
    data.each do |d|
      c = d["corrects"].inject(Hash.new(0)) { |total, e| total[e] += 1 ;total}
      wrong = 0
      correct = 0
      c.keys.each do |ck|
        if ck == false
          wrong =  (c[ck]/d["count"].to_f)*100
          correct = 100 - wrong
        else
          correct = (c[ck]/d["count"].to_f)*100
          wrong = 100 - correct
        end
      end
      q_data << {:q_id => d["question_id"],:wrong=>wrong.round(2),:correct=>correct.round(2),:section=>d["section"]}
    end

    q_data.each do |qd|
      section_hash.keys.each do |sec|
        section_hash[sec].keys.each do |sd|
          if qd[:wrong].between?(sd.first,sd.last) && sec == qd[:section]
            section_hash[sec][sd] << qd
          end
        end
      end
    end

    section_data = []
    section_hash.keys.each do |k|
      section_data << {"name"=>k,"q_data"=>section_hash[k].values,:range=>20}
    end

    attempt_data = []
    data.each do |d|
      c = d["corrects"].inject(Hash.new(0)) { |total, e| total[e] += 1 ;total}
      wrong = 0
      correct = 0
      c.keys.each do |ck|
        if ck == false
          wrong =  (c[ck]/d["count"].to_f)*100
          correct = 100 - wrong
        else
          correct = (c[ck]/d["count"].to_f)*100
          wrong = 100 - correct
        end
      end
      un = d["attempt_type"].inject(Hash.new(0)) { |total, e| total[e] += 1 ;total}
      un_attempted = 0
      attempted = 0
      un.keys.each do |uk|
        if uk == "un_attempted" or uk == "skipped"
          un_attempted = (un[uk]/d["count"].to_f)*100
          attempted = 100 - un_attempted
        else
          attempted = (un[uk]/d["count"].to_f)*100
          un_attempted = 100 - attempted
        end
      end
      attempt_data << {:q_id => d["question_id"],:wrong=>wrong.round(2),:correct=>correct.round(2),:section=>d["section"],:attempted=>attempted,:un_attempted=>un_attempted,
                 :concept=>d["concept"],:difficulty=>d["difficulty"],:q_type=>d["question_type"],:avg_time=>d["avg_time"]
      }
    end

    return {:section_data=>section_data,:questions_data=>attempt_data}
  end


end


