class Api::V1::StudentsController < ApplicationController

  def assessments
    group_ids = UserManagementServer.get_group_ids(current_user.id,current_user.token)

    data = []
    qtgs = QuizTargetedGroup.where(:group_ids.in=>group_ids, is_cancelled:false) + QuizTargetedGroup.where(:user_ids.in=>[current_user.id], is_cancelled:false)
    qtgs.uniq.each do |qtg|
      d = {}
      d['publish_id'] = qtg.id
      d['subject'] = 'Physics'
      d['sections'] = qtg.group_ids.map{|g_id| (UserManagementServer.get_group_details(g_id,current_user.token)['name'] rescue 'Group not found')}
      d['published_on'] = qtg.published_on.to_i
      d['time_open'] = qtg.time_open
      d['time_close'] = qtg.time_close

      quiz = Quiz.find(qtg.quiz_id)
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
      d['no_of_times_attempted'] = QuizAttemptData.where("data.asset_download_id"=>quiz.guid,user_id:current_user.id.to_s).count

      data << d
    end

    render json: data
  end

  def assessment_details
    qtg = QuizTargetedGroup.find(params[:publish_id])
    d = {}
    d['publish_id'] = qtg.id
    d['subject'] = 'Physics'
    d['sections'] = qtg.group_ids.map{|g_id| (UserManagementServer.get_group_details(g_id,current_user.token)['name'] rescue 'Group not found')}
    d['published_on'] = qtg.published_on.to_i
    d['time_open'] = qtg.time_open
    d['time_close'] = qtg.time_close

    quiz = Quiz.find(qtg.quiz_id)
    d['quiz_id'] = quiz.id
    d['name'] = quiz.name
    d['marks'] = quiz.total_marks
    d['no_of_questions'] = quiz.question_ids.count
    d['duration'] = quiz.total_time
    d['type'] = quiz.type

    concept_guids = JSON.parse(quiz.focus_area).map{|d| d['guid']} rescue []
    d['chapter_concepts'] = (ContentServer.get_concept_chapters(concept_guids,current_user.token).values rescue {})
    render json: d

    # data = ContentServer.get_concept_chapters(['concept_guids'],current_user.token).values
    # render json: data
  end

  def search_assessments
    if params[:subject_guids].present? && params[:search_string].present?
      group_ids = UserManagementServer.get_group_ids(current_user.id,current_user.token) rescue []

      data = []
      qtgs = QuizTargetedGroup.where(:group_ids.in=>group_ids, is_cancelled:false) + QuizTargetedGroup.where(:user_ids.in=>[current_user.id], is_cancelled:false)
      qtgs.uniq.each do |qtg|
        d = {}
        d['publish_id'] = qtg.id
        d['subject'] = 'Physics'
        d['sections'] = qtg.group_ids.map{|g_id| (UserManagementServer.get_group_details(g_id,current_user.token)['name'] rescue 'Group not found')}
        d['published_on'] = qtg.published_on.to_i
        d['time_open'] = qtg.time_open
        d['time_close'] = qtg.time_close

        quiz = Quiz.find(qtg.quiz_id)
        d['quiz_id'] = quiz.id
        d['name'] = quiz.name
        d['marks'] = quiz.total_marks
        d['no_of_questions'] = quiz.question_ids.count
        d['duration'] = quiz.total_time
        d['type'] = quiz.type
        d['no_of_times_attempted'] = QuizAttemptData.where("data.asset_download_id"=>quiz.guid,user_id:current_user.id.to_s).count

        data << d
      end

      render json: data
    else
      render json: {}
    end
  end

end