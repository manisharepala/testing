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

  def self.process_quiz_attempt_data(qad_id)
    qad = QuizAttemptData.find(qad_id)
    data = qad.data
    quiz = Quiz.where(guid:data['asset_download_id'])[0]
    quiz_json = JSON.parse(quiz.quiz_json)
    quiz_json_questions = quiz_json['questions']
    question_attempts_attributes = []


    data['timeline'].each do |q_data|
      d = {}
      d['question_json'] = quiz_json_questions.select {|q| q["id"] == q_data['question_id']}[0]
      d['start_time'] = q_data['sessions'].first['start_time'].to_time.to_i
      d['end_time'] = q_data['sessions'].last['end_time'].to_time.to_i
      d['time_taken'] = q_data['sessions'].map{|s| (s['end_time'].to_time.to_i - s['start_time'].to_time.to_i)}.sum
      d['correct'] = data['correct'].include? q_data['question_id']
      d['marks_scored'] = (d['correct'] == true)? d['question_json']['marks']: d['question_json']['penalty']

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

      elsif ['FibQuestion'].include? d['question_json']['question_type']
        question_fill_blank_attempts_attributes = []

      end
      question_attempts_attributes << d
    end

    attempt_no = QuizAttempt.where(user_id:qad.user_id,quiz_guid:data['asset_download_id']).count + 1

    quiz_attempt_data = {publish_id:data['publish_id'], user_id:qad.user_id,book_guid:data['book_id'],quiz_guid:data['asset_download_id'],attempt_no:attempt_no,marks_scored:data['score'], total_marks:quiz.total_marks,start_time:data['start_time'],end_time:data['end_time'],active_duration:data['active_duration'],question_attempts_attributes:question_attempts_attributes}
    QuizAttempt.create(quiz_attempt_data)
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
    user_result = QuizAttemptData.collection.aggregate([user_match_stage,group_stage,project_stage,sort_stage],disk_stage)

    user_data = JSON.load(user_result.to_json)
   rescue
    user_result = []
   end

    begin
    topper_result = QuizAttemptData.collection.aggregate([topper_match_stage,group_stage,project_stage,sort_stage],disk_stage)

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


end