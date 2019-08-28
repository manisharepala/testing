class Api::V1::ApiController < ApplicationController

  def marks_tags
    data = []
    TagsServer.get_tags_by_name('marks').each do |d|
      data << {'guid'=>d['guid'],'name'=>d['value'],'marks'=>d['value'].split(' ')[0],'recommend_duration'=>1}
    end
    render json: data
  end

  def get_gradewise_subject_tags
    data = {}
    data['grades'] = []

    TagsServer.get_child_tags(TagsServer.get_tag_guid('course','cbse'))['grade'].each do |d|
      data['grades'] << {'guid'=>d['guid'],'value'=>d['value'],'subjects'=>TagsServer.get_child_tags(d['guid'])['subject']}
    end
    render json: data
  end

  def difficulty_tags
    data = []
    TagsServer.get_tags_by_name('difficulty_level').each do |d|
      data << {'guid'=>d['guid'],'name'=>d['value'],'recommend_duration'=>1}
    end
    render json: data
  end

  def get_recommended_questions_count_by_tags
    data = []
    concept_questions_map = {}
    tag_questions_map = {}

    tags = params[:difficulty_tags].present?? params[:difficulty_tags] : params[:mark_tags]

    params[:chapters].each do |chapter_data|
      d = {}
      d['guid'] = chapter_data['guid']
      d['name'] = chapter_data['name']
      d['concepts'] = []
      chapter_data['concepts'].each do |concept_data|
        tag_key = "cbse_#{params[:grade]['name']}_#{params[:subject]['name']}_#{chapter_data['name']}_#{concept_data['name']}"
        tag_guid = TagsServer.get_tag_guid_by_key(tag_key)
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

    render json: data
  end

  def get_questions_by_tags
    data = {}
    question_replacement_map = {}
    final_question_ids = []

    params[:chapters].each do |chapter_data|
      chapter_data['concepts'].each do |concept_data|
        tag_key = "cbse_#{params[:grade]['name']}_#{params[:subject]['name']}_#{chapter_data['name']}_#{concept_data['name']}"
        tag_guid = TagsServer.get_tag_guid_by_key(tag_key)
        if tag_guid.present?
          concept_data['tags'].each do |difficulty_tag_data|
            question_ids = Question.all_in(:tag_ids.in=>[tag_guid,difficulty_tag_data['guid']]).map(&:id)
            q_ids = question_ids.sample(difficulty_tag_data['final_questions'])
            final_question_ids << q_ids

            q_ids.each do |q_id|
              question_replacement_map[q_id] = question_ids - q_ids
            end
          end
        end
      end
    end

    questions_data = []
    final_question_ids.flatten.each do |id|
      q = Question.find(id)
      questions_data << q.as_json(with_key:true,with_language_support:false)
    end

    data['questions_data'] = questions_data
    data['question_replacement_map'] = question_replacement_map

    render json: data
  end

  def get_question_json
    render json: Question.find(params[:id]).as_json(with_key:true,with_language_support:false)
  end

  def generate_quiz
    if params[:quiz_type].downcase == 'objective'
      player = 'challenge test'
    else
      player = 'subjective'
    end
    total_marks = params[:question_ids].map{|id| Question.find(id).default_mark}.sum

    quiz = Quiz.create(quiz_language_specific_datas_attributes: [{name:params[:name],language: 'english'}],question_ids:params[:question_ids],type:player, player:player, total_marks:total_marks, total_time:params[:duration],created_by:current_user.id)
    quiz.quiz_json = quiz.as_json(with_key:true,with_language_support:false)
    quiz.final = true
    quiz.tags_verified = true
    quiz.save!

    render json: {'success'=>true}
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



end