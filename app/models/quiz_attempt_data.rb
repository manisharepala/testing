class QuizAttemptData
  include Mongoid::Document
  include Mongoid::Timestamps
  field :data, type: BSON::Binary
  field :user_id, type: String

  index({:user_id=>1})
  index({'data.asset_download_id' => 1,:user_id=>1})
  index({'data.asset_download_id' => 1,:user_id=>1,'data.player_subtype'=>1})

  def self.process_quiz_attempt_data(qad_id)
    qad = QuizAttemptData.find(qad_id)
    data = qad.data
    quiz = Quiz.where(:guid.in=>data['asset_download_id'])[0]
    quiz_json = quiz.quiz_json
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

    quiz_attempt_data = {publish_id:data['publish_id'], user_id:qad.user_id,book_guid:data['book_id'],quiz_id:data['asset_download_id'],attempt_no:data['attempt_no'],marks_scored:data['score'], total_marks:quiz.total_marks,start_time:data['start_time'],end_time:data['end_time'],active_duration:data['active_duration'],question_attempts_attributes:question_attempts_attributes}
    QuizAttempt.create(quiz_attempt_data)
  end

end