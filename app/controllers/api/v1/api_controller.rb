class Api::V1::ApiController < ApplicationController

  def get_tags
    if params['quiz_type'] == 'objective'
      render json: TagsServer.get_tags_by_name('marks',PublisherQuestionBank.get_tags_db_id('')).map{|d| {'guid'=>d['guid'],'name'=>d['value'],'marks'=>d['value'].split(' ')[0],'recommend_duration'=>1}}
    else
      render json: TagsServer.get_tags_by_name('difficulty_level',PublisherQuestionBank.get_tags_db_id('')).map{|d| {'guid'=>d['guid'],'name'=>d['value'],'recommend_duration'=>1}}
    end
  end

  def marks_tags
    render json: TagsServer.get_tags_by_name('marks',PublisherQuestionBank.get_tags_db_id('')).map{|d| {'guid'=>d['guid'],'name'=>d['value'],'marks'=>d['value'].split(' ')[0],'recommend_duration'=>1}}
  end

  def difficulty_tags
    render json: TagsServer.get_tags_by_name('difficulty_level',PublisherQuestionBank.get_tags_db_id('')).map{|d| {'guid'=>d['guid'],'name'=>d['value'],'recommend_duration'=>1}}
  end

  def get_gradewise_subject_tags
    data = {}
    data['grades'] = []

    TagsServer.get_child_tags(TagsServer.get_tag_guid('course','cbse',PublisherQuestionBank.get_tags_db_id('')))['grade'].each do |d|
      data['grades'] << {'guid'=>d['guid'],'value'=>d['value'],'subjects'=>TagsServer.get_child_tags(d['guid'])['subject']}
    end
    render json: data
  end

  def get_recommended_questions_count_by_tags
    data = []
    concept_questions_map = {}
    tag_questions_map = {}

    tags = params[:tags]
    course_name = TagsServer.get_tag_parent_data(params['grade']['guid'])['value']

    params[:chapters].each do |chapter_data|
      d = {}
      d['guid'] = chapter_data['guid']
      d['name'] = chapter_data['name']
      d['concepts'] = []
      chapter_data['concepts'].each do |concept_data|
        tag_key = "#{course_name}_#{params[:grade]['name']}_#{params[:subject]['name']}_#{chapter_data['name']}_#{concept_data['name']}"
        tag_guid = TagsServer.get_tag_guid_by_key(tag_key,PublisherQuestionBank.get_tags_db_id(''))
        if tag_guid.present?
          d1 = {}
          d1['guid'] = concept_data['guid']
          d1['name'] = concept_data['name']
          concept_questions_map[concept_data['guid']] ||= []
          d1['tags'] = []

          tags.each do |difficulty_tag_data|
            tag_questions_map[difficulty_tag_data['guid']] ||= []
            questions = Question.all_in(:tag_ids.in=>[tag_guid,difficulty_tag_data['guid']])
            d1['tags'] << {'guid'=>difficulty_tag_data['guid'],'name'=>difficulty_tag_data['name'],'recommended_questions'=>0,'no_of_questions_available'=>questions.count}

            concept_questions_map[concept_data['guid']] << questions.map(&:guid)
            tag_questions_map[difficulty_tag_data['guid']] << questions.map(&:guid)
          end

          d['concepts'] << d1
        end
      end
      data << d
    end

    balanced_questions = {}
    tags.each do |difficulty_tag_data|
      balanced_questions[difficulty_tag_data['guid']] = difficulty_tag_data['required_questions']
    end

    balanced_questions.keys.each do |difficulty_tag_key|
      loop do
        if balanced_questions[difficulty_tag_key] > 0
          balance_questions_count_at_start = balanced_questions[difficulty_tag_key]

          ##########################
          chapter_index = [*0..data.count-1].sample
          [data[chapter_index]].each_with_index do |chapter_data,i|
            concept_index = [*0..chapter_data['concepts'].count-1].sample
            [chapter_data['concepts'][concept_index]].each_with_index do |concept_data,j|
              tag_index = 0
              concept_data['tags'].each_with_index do |d,k|
                if d['guid'] == difficulty_tag_key
                  tag_index = k
                  break
                end
              end
              if (concept_data['tags'][tag_index]['recommended_questions'] < concept_data['tags'][tag_index]['no_of_questions_available']) && (balanced_questions[difficulty_tag_key] > 0)
                concept_data['tags'][tag_index]['recommended_questions'] += 1
                chapter_data['concepts'][concept_index] = concept_data
                balanced_questions[difficulty_tag_key] -= 1
              end
            end
            data[chapter_index] = chapter_data
          end
          ###########################

          if balanced_questions[difficulty_tag_key] < balance_questions_count_at_start
          else
            break
          end
        else
          break
        end
      end
    end

    summary = {}
    by_tags = tags.map{|a| a.merge('serving_questions'=>data.map{|b| b['concepts']}.flatten.map{|c| c['tags']}.flatten.select{|d| d['guid'] == a['guid']}.flatten.map{|e| e['recommended_questions']}.sum)}
    summary['total_questions_required']= tags.map{|a| a['required_questions']}.sum
    summary['total_questions_serving'] = by_tags.map{|e| e['serving_questions']}.sum
    summary['by_tags'] = by_tags

    render json: {'summary'=>summary,'chapters'=>data}
  end

  def get_questions_by_tags
    final_question_ids = []
    course_name = TagsServer.get_tag_parent_data(params['grade']['guid'])['value']
    params[:chapters].each do |chapter_data|
      chapter_data['concepts'].each do |concept_data|
        tag_key = "#{course_name}_#{params[:grade]['name']}_#{params[:subject]['name']}_#{chapter_data['name']}_#{concept_data['name']}"
        tag_guid = TagsServer.get_tag_guid_by_key(tag_key,PublisherQuestionBank.get_tags_db_id(''))
        if tag_guid.present?
          concept_data['tags'].each do |difficulty_tag_data|
            question_ids = Question.all_in(:tag_ids.in=>[tag_guid,difficulty_tag_data['guid']]).map(&:id)
            q_ids = question_ids.sample(difficulty_tag_data['final_questions'])
            final_question_ids << q_ids
          end
        end
      end
    end

    render json: Question.where(:id.in=>final_question_ids.flatten).map{|q| q.as_json(with_key:true,with_language_support:false)}
  end

  def get_replacement_question
    render json: Question.all_in(:tag_ids.in =>Question.find(params[:id]).tag_ids)[0].as_json(with_key:true,with_language_support:false)
  end

  def generate_quiz
    data = {}
    begin
      if params[:quiz_type].downcase == 'objective'
        player = 'challenge_test'
      else
        player = 'subjective'
      end
      total_marks = params[:question_ids].map{|id| Question.find(id).default_mark}.sum

      quiz = Quiz.create!(quiz_language_specific_datas_attributes: [{name:params[:name],language: 'english'}],question_ids:params[:question_ids],type:player, player:player, total_marks:total_marks, total_time:params[:duration],created_by:current_user.id)
      quiz.quiz_json = quiz.as_json(with_key:true,with_language_support:false)
      quiz.final = true
      quiz.tags_verified = true
      quiz.save!

      if quiz.present?
        data['quiz_id'] = quiz.id
        data['success'] = true
      else
        data['success'] = false
      end
    rescue
      data['success'] = false
    end

    render json: data
  end

  def publish_assessment
    data = {}
    begin
      quiz_targeted_group_data = {password:params[:password], time_open:params[:time_open].to_i, time_close:params[:time_close].to_i, show_score_after:params[:show_score_after], show_answers_after:params[:show_answers_after], published_by:current_user.id, group_ids:params[:group_ids], user_ids:params[:user_ids], message_subject:params[:message_subject], message_body:params[:message_body],quiz_id:params[:quiz_id],shuffle_questions:params[:shuffle_questions],shuffle_options:params[:shuffle_options],pause:params[:pause],max_no_of_attempts:params[:max_no_of_attempts]}

      qtg = QuizTargetedGroup.create!(quiz_targeted_group_data)

      if qtg.present?
        data['publish_id'] = qtg.id
        data['success'] = true
      else
        data['success'] = false
      end
    rescue
      data['success'] = false
    end

    render json: data
  end

  def assessments
    data = []
    qtgs = QuizTargetedGroup.where(:group_ids.in=>[params[:section_id].to_i],published_by:current_user.id, is_cancelled:false)
    qtgs.uniq.each do |qtg|
      quiz = Quiz.find(qtg.quiz_id)

      quiz_subject = TagsServer.get_tags_data(quiz.tag_ids).select{|d| d['name'] == 'subject'}[0]['value'] rescue ''

      if !params[:subject].present? || (quiz_subject.downcase == params[:subject].downcase rescue false)
        d = {}
        d['publish_id'] = qtg.id
        d['subject'] = quiz_subject
        d['from'] = UserManagementServer.get_user_details(qtg.published_by,current_user.token)['name'] rescue ''
        d['to'] = qtg.user_ids.map{|u_id| (UserManagementServer.get_user_details(u_id,current_user.token)['name'])} + qtg.group_ids.map{|g_id| (UserManagementServer.get_group_details(g_id,current_user.token)['name'])} rescue []
        d['published_on'] = qtg.published_on.to_i
        d['time_open'] = qtg.time_open
        d['time_close'] = qtg.time_close

        d['quiz_id'] = quiz.id

        d['guid'] = quiz.guid
        d['download_id'] = quiz.guid
        d['src'] = 'assessment.json'
        d['player'] = 'assessment'
        d['name'] = quiz.name

        d['marks'] = quiz.total_marks
        d['no_of_questions'] = quiz.question_ids.count
        d['duration'] = quiz.total_time
        d['type'] = quiz.type

        data << d
      end
    end

    render json: data
  end

  def merge_assessments
    # Quiz.where(:id.in=>(Quiz.all.map(&:id) - Quiz.where(chapters:nil).map(&:id))).each do |quiz|
    #   quiz.update_attributes(type:'multi_chapter_test',player:'multi_chapter_test')
    #   quiz.upload_zip
    # end

    all_question_ids = Quiz.where(:guid.in=>params['assessment_guids']).map{|q| q.all_question_ids}.flatten.uniq

    data = {}
    begin
      total_marks = Question.where(:id.in=>all_question_ids).map{|q| q.default_mark}.sum

      quiz = Quiz.create!(quiz_language_specific_datas_attributes: [{name:params['name'],description:params['description'],instructions:params['instructions'],language: 'english'}],question_ids:all_question_ids,type:params['quiz_type'], player:params['quiz_type'], total_marks:total_marks, total_time:params['duration'],tag_ids:((params['grades'] + params['subjects']) rescue []),created_by:(current_user.id rescue nil),chapters:params.to_unsafe_h['chapters'])

      if quiz.present?
        quiz.quiz_json = quiz.as_json(with_key:true,with_language_support:false)
        quiz.final = true
        quiz.tags_verified = true
        quiz.save!
        quiz.update_test_topic_details

        data = {'success'=>true,'asset_download_id'=>quiz.guid,'assessment_guid'=>quiz.guid,'test_download_id'=>quiz.guid}
      else
        data['success'] = false
      end
    rescue
      data['success'] = false
    end

    render json: data
  end

  def test_analytics
    params = {'published_id'=>'5daeafecfdbd26239540315b','group_id'=>314}
    token = "eyJhbGciOiJIUzI1NiJ9.eyJ1c2VybmFtZSI6bnVsbCwiZW1haWwiOiJjbGFzc182X3RlYWNoZXJfMV8xNTUyOTkwOTU4X0B2YXJzaXR5LmNvbSIsInJvbGxfbm8iOm51bGwsInVzZXJfaWQiOjM2Mywic3ViIjoiMzYzIiwic2NwIjoidXNlciIsImF1ZCI6bnVsbCwiaWF0IjoxNTU2NTE1MDgyLCJleHAiOjE1NTY2MDE0ODIsImp0aSI6Ijk5YWJiYTFiLTAwNjMtNDg2My1hZWFhLWExM2M0ZWM5ZWEwNSJ9.PT0uU986H3XBAELUzWyp9CD1uLzvrUlSpPCsFaVqE3I"
    qtg = QuizTargetedGroup.find(params['published_id'])
    quiz = Quiz.find(qtg.quiz_id)

    data = {}

    if quiz.present?
      data['name'] = quiz.name
      tags_data = TagsServer.get_tags_data(quiz.tag_ids)
      data['subjects'] = tags_data.select{|a| a['name'] == 'subject'}.map{|b| b['value']}
      data['grades'] = tags_data.select{|a| a['name'] == 'grade'}.map{|b| b['value']}
      data['type'] = quiz.type

      students_data = UserManagementServer.get_students_in_group(params['group_id'],token)
      students_id_name_map = students_data{|a| {a['id']=>a['name']}}.reduce(:merge)
      quiz_attempts = QuizAttempt.where(published_id:params['published_id'],:user_id.in=>students_data.map{|s| s['id']},attempt_no:1)
      attempted_student_ids = quiz_attempts.map(&:user_id)
      data['attempted_students_count'] = attempted_student_ids.count
      data['total_students_count'] = students_data.count
      data['un_attempted_students'] = students_data.select{|s| (!attempted_student_ids.include? s['id'])}.map{|a| {'id'=>a['id'],'name'=>a['name']}}

      marks_scored = quiz_attempts.map(&:marks_scored)
      time_taken = quiz_attempts.map(&:active_duration)
      data['top_score'] = marks_scored.max
      min_score_in_top_3 = marks_scored.max(3).min
      data['top_3_scores'] = quiz_attempts.select{|a| a['marks_scored'] >= min_score_in_top_3}.map{|qa| {'id'=>qa['user_id'],'name'=>students_id_name_map[qa['user_id']],'marks_scored'=>qa.marks_scored}}

      data['total_marks'] = quiz.get_total_marks

      data['average_score'] = (marks_scored.sum/marks_scored.count).round(1)
      data['marks_scored_by_each_student'] = quiz_attempts.map{|qa| {'id'=>qa['user_id'],'name'=>students_id_name_map[qa['user_id']],'marks_scored'=>qa['marks_scored']}}

      data['average_time_taken_for_quiz'] = (time_taken.sum/time_taken.count*60).round(1)
      data['time_taken_by_each_student'] = quiz_attempts.map{|qa| {'id'=>qa['user_id'],'name'=>students_id_name_map[qa['user_id']],'time_taken'=>(qa['active_duration']/60.0).round}}

      question_wise_data = {}
      quiz_attempts.each do |quiz_attempt|
        quiz_attempt.question_attempts.each do |qa|
          question_wise_data[qa.question_id] ||= {'correct'=>[],'time_taken'=>[]}
          question_wise_data[qa.question_id]['correct'] << qa.correct
          question_wise_data[qa.question_id]['time_taken'] << qa.time_taken
        end
      end

      question_ids = quiz.all_question_ids
      data['individual_question_correct_percentage'] = question_wise_data.map{|k,v| {'id'=>k,'question_number'=>"Q#{question_ids.find_index(k)+1}",'correct_percentage'=>(v['correct'].count(true)/v['correct'].count.to_f).rond(1)}}.sort_by{|a| a['correct_percentage']}.reverse

      data['most_difficult_question'] = data['question_wise_correct_percentage'][0]

      data['average_time_per_question'] = (data['average_time_for_quiz']/quiz.total_questions).round(1)
      data['individual_question_average_time'] =  question_wise_data.map{|k,v| {'id'=>k,'question_number'=>"Q#{question_ids.find_index(k)+1}",'time_taken'=>(v['time_taken'].sum/v['time_taken'].count.to_f).rond(1)}}

    end

    render json: data
  end

end