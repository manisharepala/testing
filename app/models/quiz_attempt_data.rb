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
    if ['jee_mains','challenge test'].include? qad.data['player_subtype'] #[15664,19040].include? qad.user_id.to_i
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
      attempt_no = QuizAttempt.where(user_id:qad.user_id.to_i,quiz_guid:quiz.guid).count + 1

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

  def self.get_user_attempt_analytics_v2(assessment,user_id)
    @source = File.read(Rails.root.join("app/assets/javascripts/rank_array.js"))
    @context = ExecJS.compile(@source)
    marks = {}
    @quiz = Quiz.where(:guid=>assessment).last
    marks[:total_questions] = @quiz.total_marks
    marks[:total_time] = @quiz.total_time

    quiz_attempt = QuizAttempt.where(:quiz_guid=>assessment,:user_id=>user_id).last
    marks[:score] = quiz_attempt.marks_scored
    marks[:accuracy] = (quiz_attempt.correct/quiz_attempt.total).to_f
    marks[:attempt_rate] = (quiz_attempt.attempted/quiz_attempt.active_duration)
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
    return marks
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
                                             {"$match"=>{"$and"=>[{"user"=>user_id},{"quiz_attempt_data_id"=>attempt_id}]}}])

    return JSON.load(data.to_json)[0]["rank"]

  end


  def self.get_quiz_max_min_details(assessment,user_id)
    data =  QuizAttempt.collection.aggregate([{"$project"=>{"user_id"=>1,"quiz_guid"=>1,"marks_scored"=>1}},
                                              {"$match"=>{"user_id"=>user_id}},
                                              {"$match"=>{"quiz_guid"=>assessment}},
                                              {"$group"=>{"_id"=>{"assessment_id"=>"$quiz_guid","user_id"=>"$user_id"},"min_marks"=>{"$min"=>"$marks_scored"},"max_marks"=>{"$max"=>"$marks_scored"},"avg_score"=>{"$avg"=>"$marks_scored"},}},
                                              {"$project"=>{"user_id"=>"$_id.user_id","max_marks"=>"$max_marks","min_marks"=>"$min_marks","avg_score"=>"$avg_score","_id"=>0}}])


    return JSON.load(data.to_json)[0]

  end


  def self.get_quiz_section_details(assessment,user_id)
    data = QuizAttempt.collection.aggregate([
                                                {"$unwind"=>"$quiz_section_attempts"},
                                                {"$project"=>{"quiz_section_attempts"=>1, "user_id"=>1,"quiz_guid"=>1,"marks_scored"=>1}},
                                                {"$match"=>{"user_id"=>user_id}},
                                                {"$match"=>{"quiz_guid"=>assessment}},

                                                {"$group"=>{"_id"=>{"assessment_id"=>"$quiz_guid","user_id"=>"$user_id","sub"=>"$quiz_section_attempts.quiz_section_name"},
                                                            "min_marks"=>{"$min"=>"$quiz_section_attempts.marks_scored"},"max_marks"=>{"$max"=>"$quiz_section_attempts.marks_scored"}, "avg_score"=>{"$avg"=>"$quiz_section_attempts.marks_scored"}}},
                                                {"$project"=>{"subject"=>"$_id.sub","max_marks"=>"$max_marks","min_marks"=>"$min_marks","avg_score"=>"$avg_score","_id"=>0}}])
    return JSON.load(data.to_json)
  end


  def self.get_quiz_section_data(assessment,user_id,attempt_id)
    @source = File.read(Rails.root.join("app/assets/javascripts/rank_array.js"))
    @context = ExecJS.compile(@source)
    section_data = []
    @quiz.quiz_section_ids.each do |section_id|

      data = QuizAttempt.collection.aggregate([{"$unwind"=>"$quiz_section_attempts"},
                                               {"$match"=>{"$and"=>[{"quiz_section_attempts.quiz_section_id"=>section_id},{"quiz_guid"=>assessment}]}},
                                               {"$project"=>{"user_id"=>1,"_id"=>0,"quiz_guid"=>1,"quiz_section_attempts"=>1,"quiz_attempt_data_id"=>1}}, {"$sort"=>{"quiz_section_attempts.marks_scored"=>-1}},
                                               {"$group"=>{"_id"=>false, "users"=>{"$push"=>{"_id"=>"$_id", "user_id"=>"$user_id","quiz"=>"$quiz_guid",
                                                                                             "sub"=>"$quiz_section_attempts.quiz_section_name","marks_scored"=>"$quiz_section_attempts.marks_scored",
                                                                                             "correct"=>"$quiz_section_attempts.correct",
                                                                                             "quiz_attempt_data_id"=>"$quiz_attempt_data_id",
                                                                                             "incorrect"=>"$quiz_section_attempts.in_correct","unattempted"=>"$quiz_section_attempts.un_attempted",
                                                                                             "skipped"=>"$quiz_section_attempts.skipped","active_duration"=>"$quiz_section_attempts.active_duration"}}}},
                                               {"$addFields"=>{"users"=>@context.call("rankArray","$users","marks_scored","dense=false")}},
                                               {"$unwind"=>{"path"=>"$users"}},
                                               {"$project"=>{"quiz_attempt_data_id"=>"$users.quiz_attempt_data_id","user"=>"$users.user_id",
                                                             "sub"=>"$users.sub","marks"=>"$users.marks_scored","rank"=>"$users.rank","correct"=>"$users.correct",
                                                             "incorrect"=>"$users.incorrect","unattempted"=>"$users.unattempted","skipped"=>"$users.skipped",
                                                             "active_duration"=>"$users.active_duration","_id"=>0}},{"$match"=>{"$and"=>[{"user"=>user_id},{"quiz_attempt_data_id"=>attempt_id}]}}])

      section_data << JSON.load(data.to_json)[0]
    end
    return section_data
  end

end

