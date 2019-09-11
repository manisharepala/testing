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
    if [15664,19040].include? self.user_id.to_i
      data = self.data
      quiz = Quiz.where(guid:data['asset_download_id'])[0]
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
        d['marks_scored'] = (d['correct'] == true)? d['question_json']['marks']: d['question_json']['penalty']
        if data['attempted'].include? q_data['question_id']
          d['attempt_type'] = 'attempted'
        elsif data['unattempted'].include? q_data['question_id']
          d['attempt_type'] = 'un_attempted'
        elsif data['skipped_questions'].include? q_data['question_id']
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
          d1['marks_scored'] = quiz_section_questions_data.map{|d| d['marks_scored']}.sum
          d1['total_marks'] = quiz_section_questions_data.map{|d| d['question_json']['marks']}.sum
          d1['active_duration'] = quiz_section_questions_data.map{|d| d['time_taken']}.sum

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
      data['marks_scored'] = question_attempts_attributes_with_sections_data.map{|d| d['time_taken']}.sum
      attempt_no = QuizAttempt.where(user_id:self.user_id.to_i,quiz_guid:data['asset_download_id']).count + 1

      total_count = question_attempts_attributes_with_sections_data.count
      attempted_count = question_attempts_attributes_with_sections_data.select{|d| d['attempt_type'] == 'attempted'}.count
      un_attempted_count = question_attempts_attributes_with_sections_data.select{|d| d['attempt_type'] == 'un_attempted'}.count
      correct_count = question_attempts_attributes_with_sections_data.select{|d| d['correct'] == true}.count
      in_correct_count = attempted_count - correct_count
      skipped_count = question_attempts_attributes_with_sections_data.select{|d| d['attempt_type'] == 'skipped'}.count

      quiz_attempt_data = {quiz_attempt_data_id:self.id.to_s,publish_id:data['publish_id'], user_id:self.user_id.to_i,book_guid:data['book_id'],quiz_guid:data['asset_download_id'],attempt_no:attempt_no,marks_scored:data['marks_scored'], total_marks:quiz.total_marks,start_time:data['start_time'].to_time.to_i,end_time:data['end_time'].to_time.to_i,active_duration:data['active_duration'],question_attempts_attributes:question_attempts_attributes_with_sections_data,quiz_section_attempts_attributes:quiz_section_attempts_attributes, total:total_count,attempted:attempted_count,un_attempted:un_attempted_count,correct:correct_count,in_correct:in_correct_count,skipped:skipped_count}
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


end