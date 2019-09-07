class ApiController < ApplicationController

  # skip_before_action :authenticate_user!

  def user_assessments_by_category
    #current_user.id = 363
    data = {}

    ['due_today','un_assigned','on_going','completed','cancelled'].each do |k|
      data[k] = []
    end

    quizzes = Quiz.where(created_by:current_user.id)
    qtgs = QuizTargetedGroup.where(published_by:current_user.id)

    (quizzes.map(&:id) - qtgs.map(&:quiz_id).map{|a| a.to_s}).each do |quiz_id|
      quiz = Quiz.find(quiz_id)
      assessment_data = {}
      assessment_data['quiz_id'] = quiz_id
      assessment_data['name'] = quiz.name
      assessment_data['subjects'] = (quiz.quiz_json.map{|h| h.values[0] if h.keys[0] == 'subject'} - [nil]) rescue []
      assessment_data['obj_sub'] = 'Objective'

      assessment_data['total_marks'] = quiz.total_marks
      assessment_data['total_questions'] = quiz.question_ids.count
      assessment_data['duration'] = quiz.total_time

      data['un_assigned'] << assessment_data
    end

    qtgs.each do |qtg|
      assessment_data = {}
      assessment_data['quiz_id'] = qtg.quiz_id.to_s
      assessment_data['publish_id'] = qtg.id
      assessment_data['name'] = qtg.quiz.name
      assessment_data['subjects'] = (qtg.quiz.quiz_json.map{|h| h.values[0] if h.keys[0] == 'subject'} - [nil]) rescue []
      assessment_data['groups'] = []
      assessment_data['users'] = []

      qtg.group_ids.each do |group_id|
        group_details = UserManagementServer.get_group_details(group_id,current_user.token) #{"id"=>43, "name"=>"class_6_Section_A", "type"=>"Section", "parent_id"=>42, "parent_name"=>"Class_6", "parent_type"=>"AcademicClass"}

        assessment_data['groups'] << {'id'=>group_details['id'],'name'=>group_details['name'],'type'=>group_details['type']}
      end

      qtg.user_ids.each do |user_id|
        user_details = UserManagementServer.get_user_details(user_id,current_user.token)

        assessment_data['users'] << {'id'=>user_details['id'],'name'=>user_details['name'],'roles'=>user_details['roles']}
      end

      assessment_data['obj_sub'] = 'Objective'
      assessment_data['time_close'] = qtg.time_close

      assessment_data['total_marks'] = qtg.quiz.total_marks
      assessment_data['total_questions'] = qtg.quiz.question_ids.count
      assessment_data['duration'] = qtg.quiz.total_time

      todays_beginning_time = Time.now.beginning_of_day.to_i
      time_close_beginning_time = Time.at(qtg.time_close).beginning_of_day.to_i

      if time_close_beginning_time == todays_beginning_time
        data['due_today'] << assessment_data
      elsif time_close_beginning_time > todays_beginning_time
        data['on_going'] << assessment_data
      elsif time_close_beginning_time < todays_beginning_time
        data['completed'] << assessment_data
      end
    end

    # data.keys.each do |k|
    #   assessment_data = {}
    #   assessment_data['quiz_id'] = 123
    #   assessment_data['publish_id'] = 1234
    #   assessment_data['name'] = 'Time is precious'
    #   assessment_data['subject'] = ['Maths','Physics']
    #   assessment_data['class'] = {'id'=>12345,'name'=>'Sixth'}
    #   assessment_data['section'] = {'id'=>12346,'name'=>'A'}
    #   assessment_data['obj_sub'] = 'Objective'
    #   assessment_data['end_date'] = '12 Aug 9 Am'
    #
    #   assessment_data['total_marks'] = 60
    #   assessment_data['total_questions'] = 20
    #   assessment_data['duration'] = 180
    #
    #   if k == 'un_assigned'
    #     assessment_data = assessment_data.except('end_date')
    #     assessment_data = assessment_data.except('publish_id')
    #   end
    #   data[k] << assessment_data
    # end

    render json: data
  end

  def edit_due_time
    data = {}
    qtg = QuizTargetedGroup.where(id:params[:publish_id])[0]
    if qtg.present?
      qtg.time_close = params[:time_close].to_i
      if qtg.save!
        data['success'] = true
      else
        data['success'] = false
      end
    else
      data['success'] = false
    end

    render json: data
  end

  def cancel_published_assessment
    data = {}
    qtg = QuizTargetedGroup.where(id:params[:publish_id])[0]
    if qtg.present?
      qtg.is_cancelled = true
      if qtg.save!
        data['success'] = true
      else
        data['success'] = false
      end
    else
      data['success'] = false
    end

    render json: data
  end

  def different_question_types_by_marks
    data = []

    (1..5).each do |i|
      d = {}
      d['name'] = "#{i} Mark Questions"
      d['marks'] = i

      data << d
    end

    render json: data
  end


  def different_question_types_by_difficulty
    data = ['Easy Questions','Medium Questions','Hard Questions']

    render json: data
  end

  def get_book_toc_structure
    ca = ContentAsset.where(asset_type:'toc').last
    d = ca.get_toc_json
    [:guid, :name, :label, :itemType, :metadata, :icon, :player, :params, :showInToc, :showInLivePage, :downloadId, :src, :rootSrc, :childs]
  end

  def assessment_details
    data = {}
    assessment_id = params[:assessment_id]

    data['id'] = 123
    data['name'] = 'Time is precious'
    data['subject'] = ['Maths','Physics']
    data['obj_sub'] = 'Objective'

    data['total_marks'] = 60
    data['total_questions'] = 20
    data['duration'] = 180

    data['chapters'] = []
    chapter_data = {}
    chapter_data['guid'] = 'asdfghjkljsdfghf'
    chapter_data['name'] = 'chapter_name'
    chapter_data['concepts'] = []

    concept_data = {}
    concept_data['guid'] = 'eartyuhgjfgdsadf'
    concept_data['name'] = 'concept_name'

    chapter_data['concepts'] << concept_data
    data['chapters'] << chapter_data

    render json: data
  end

  def user_tags_by_category
    data = {}
    data['grades'] = []
    data['subjects'] = []

    d = TagsServer.get_uniq_tag_values_with_guids

    data['grades'] << d['grade']
    data['subjects'] << d['subject']

    render json: data
  end

  def create_duplicate_assessment
    data = {}
    assessment_id = params[:assessment_id]

    name = params[:name]
    duration = params[:duration]

    data['assessment_id'] = 4
    data['success'] = true
    render json: data
  end

  def question_types
    data = {}
    data['objective'] = []
    data['subjective'] = []

    o1 = {'name' => "1 Mark Questions", 'marks' => 1}
    o2 = {'name' => "2 Mark Questions", 'marks' => 2}
    o3 = {'name' => "3 Mark Questions", 'marks' => 3}
    o4 = {'name' => "5 Mark Questions", 'marks' => 5}

    s1 = {'name' => "Easy Questions", 'marks' => 1}


    s2 = {'name' => "Medium Questions", 'marks' => 2}
    s3 = {'name' => "Hard Questions", 'marks' => 4}

    data['objective'] << o1
    data['objective'] << o2
    data['objective'] << o3
    data['objective'] << o4

    data['subjective'] << s1
    data['subjective'] << s2
    data['subjective'] << s3

    render json: data
  end

  def get_chapters_and_concepts_by_tags
    grade_guids = params[:grade_guids]
    subject_guids = params[:subject_guids]


  end

  def get_assessments_by_tags
    grade_guids = params[:grade_guids]
    subject_guids = params[:subject_guids]


  end

  def teacher_class_subjects
    data = {}
    data['sections'] = []
    data['subjects'] = []



    render json: data
  end
end