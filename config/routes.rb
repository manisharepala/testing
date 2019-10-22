require 'sidekiq/web'
Rails.application.routes.draw do

  mount Ckeditor::Engine => '/ckeditor'
  mount Sidekiq::Web, at: '/sidekiq'

  get '/assessment/get_assessment_group_topic_details/:guid', to: 'quizzes#get_assessment_group_topic_details'
  get '/assessment/get_group_assessment_subject_details/:guid', to: 'quizzes#get_group_assessment_subject_details'
  get '/assessment/get_group_assessment_rank_data/:guid', to: 'quizzes#get_group_assessment_rank_data'
  get '/assessment/get_group_assessment_analytics/:guid',to: 'quizzes#get_group_assessment_analytics'

  get '/assessment/get_user_quiz_attempt_topic_details/:guid', to: 'quizzes#get_user_quiz_attempt_topic_details'
  get '/assessment/get_quiz_question_attempts/:guid', to: 'quizzes#get_quiz_question_attempts'
  get '/assessment/get_user_attempt_analytics_v1/:guid', to: 'quizzes#get_user_attempt_analytics_v1'
  get '/assessment/get_user_attempt_analytics/:guid', to: 'quizzes#get_user_attempt_analytics'
  match '/assessment/get_given_quiz_topic_analytics', to: 'quizzes#get_given_quiz_topic_analytics', via: [:get, :post]
  match '/assessment/get_given_quiz_analytics', to: 'quizzes#get_given_quiz_analytics', via: [:get, :post]


  get '/assessment/get_assessment_attempts/:book_id', to: 'quizzes#get_all_assessment_attempts'
  get '/assessment/get_assessment_attempt/:attempt_id', to: 'quizzes#get_assessment_attempt_by_attempt_id'

  get '/assessment/ckeditor/pictures', to: 'ckeditor/pictures#index'
  post '/assessment/ckeditor/pictures', to: 'ckeditor/pictures#create'

  post '/assessment/quiz_attempt_data', to: 'application#quiz_attempt_data'
  post '/assessment/multi_chapter_quiz_attempt_data', to: 'application#multi_chapter_quiz_attempt_data'

  get "/assessment/zip_upload_question" => "quizzes#zip_upload_question"
  post "/assessment/post_zip_upload_question" => "quizzes#post_zip_upload_question"
  get "/assessment/zip_upload_only_questions" => "quizzes#zip_upload_only_questions"
  post "/assessment/post_zip_upload_only_questions" => "quizzes#post_zip_upload_only_questions"

  get "/assessment/migrate_quiz" => "quizzes#migrate_quiz"

  get '/assessment/quizzes/download_pdf', to: 'quizzes#show'


  post "/assessment/process_migrate_quiz" => "quizzes#process_migrate_quiz"
  post '/assessment/bulk_migrate_quizzes', to: 'quizzes#bulk_migrate_quizzes'

  get '/assessment/all_quizzes', to: 'quizzes#all_quizzes'
  get '/assessment/quiz_questions', to: 'quizzes#quiz_questions'
  get '/assessment/question/show', to: 'questions#show'
  get '/assessment/question/edit', to: 'questions#edit'
  post '/assessment/question/update', to: 'questions#update'

  get '/assessment/quiz_sections', to: 'sections#get_quiz_sections'
  get '/assessment/section_questions', to: 'sections#section_questions'
  get 'assessment/section/edit', to: 'sections#section_edit'
  get 'assessment/section/show', to: 'sections#section_show'
  post 'assessment/section/update', to: 'sections#section_update'

  get '/assessment/get_quizzes', to: 'quizzes#get_quizzes'
  get '/assessment/get_quiz_json', to: 'quizzes#get_quiz_json'

  get '/assessment/quiz/new', to: 'quizzes#new'
  post '/assessment/quiz/create', to: 'quizzes#create'

  get '/assessment/get_focus_area', to: 'quizzes#get_focus_area'
  post '/assessment/update_focus_area', to: 'quizzes#update_focus_area'

  get '/assessment/quiz/add_questions', to: 'questions#add_questions'
  post '/assessment/quiz/add_questions', to: 'questions#add_questions'
  get '/assessment/quiz/edit', to: 'quizzes#quiz_edit'
  post '/assessment/quiz/update', to: 'quizzes#quiz_update'
  get '/assessment/quiz/delete', to: 'quizzes#quiz_delete'
  get "/assessment/quiz/publish"=>"quizzes#publish_to"
  post "/assessment/quiz/publish"=>"quizzes#publish"

  post "/assessment/quiz/create_individual_question", to: 'questions#create_individual_question'
  get "/assessment/quiz/create_individual_question", to: 'questions#create_individual_question'
  get '/assessment/quiz/preview_assessment', to: 'quizzes#preview_assessment'

  post '/assessment/questions/get_questions_by_live_tags', to: 'questions#get_questions_by_live_tags'
  get '/assessment/questions/get_questions_by_live_tags', to: 'questions#get_questions_by_live_tags'
  get '/assessment/questions/import_questions', to: 'questions#import_questions'
  post '/assessment/questions/import_questions', to: 'questions#import_questions'
  get '/assessment/quiz/add_questions_from_import', to: 'questions#add_questions_from_import'

  post '/assessment/get_quizzes_analytics_data', to: 'quizzes#get_quizzes_analytics_data'
  post '/assessment/get_chapter_level_quizzes_analytics_data', to: 'quizzes#get_chapter_level_quizzes_analytics_data'
  post '/assessment/get_concept_wise_quizzes_analytics_data', to: 'quizzes#get_concept_wise_quizzes_analytics_data'
  post '/assessment/get_assessments_attempted_count', to: 'quizzes#get_assessments_attempted_count'
  post '/assessment/get_are_assessments_attempted', to: 'quizzes#get_are_assessments_attempted'
  post '/assessment/get_assessments_active_duration', to: 'quizzes#get_assessments_active_duration'
  post '/assessment/get_assessments_attempt_data', to: 'quizzes#get_assessments_attempt_data'
  get '/assessment/get_book_assessments_attempted/:book_id/:user_id', to: 'quizzes#get_book_assessments_attempted'

  get '/assessment/get_quiz_attempt_data', to: 'quizzes#get_quiz_attempt_data'
  get '/assessment/challenge_test_attempt_data', to: 'quizzes#challenge_test_attempt_data'
  get '/assessment/get_multi_chapter_quiz_attempt_data', to: 'quizzes#get_multi_chapter_quiz_attempt_data'

  get '/assessment/get_all_quiz_attempt_datas', to: 'quizzes#get_all_quiz_attempt_datas'
  get '/assessment/get_quiz_attempt_data_by_id', to: 'quizzes#get_quiz_attempt_data_by_id'

#teacher web api's
  get '/assessment/user_assessments_by_category', to: 'api#user_assessments_by_category'
  post '/assessment/edit_due_time', to: 'api#edit_due_time'
  post '/assessment/cancel_published_assessment', to: 'api#cancel_published_assessment'

  get '/assessment/different_question_types_by_marks', to: 'api#different_question_types_by_marks'
  get '/assessment/different_question_types_by_difficulty', to: 'api#different_question_types_by_difficulty'


  get '/assessment/assessment_details', to: 'api#assessment_details'
  get '/assessment/user_tags_by_category', to: 'api#user_tags_by_category'
  post '/assessment/create_duplicate_assessment', to: 'api#create_duplicate_assessment'

  post '/assessment/get_child_tags', to: 'tags#get_child_tags'
  get '/assessment/update_question_tags', to: 'tags#update_question_tags'

  post '/assessment/questions/preview_section', to: 'questions#preview_section'

  scope '/assessment' do
    scope '/apis' do
      scope '/v1' do
        get '/student/assessments' => 'api/v1/students#assessments'
        get '/assessment_details' => 'api/v1/students#assessment_details'
        post '/search_assessments' => 'api/v1/students#search_assessments'

        get '/get_gradewise_subject_tags' => 'api/v1/api#get_gradewise_subject_tags'
        get '/marks_tags' => 'api/v1/api#marks_tags'
        get '/difficulty_tags' => 'api/v1/api#difficulty_tags'
        post '/get_recommended_questions_count_by_tags' => 'api/v1/api#get_recommended_questions_count_by_tags'
        post '/get_questions_by_tags' => 'api/v1/api#get_questions_by_tags'
        get '/get_question_json' => 'api/v1/api#get_question_json'
        post '/generate_quiz' => 'api/v1/api#generate_quiz'
        post '/publish_assessment' => 'api/v1/api#publish_assessment'

        get '/teacher/assessments' => 'api/v1/api#assessments'

        post '/merge_assessments' => 'api/v1/api#merge_assessments'
      end
    end
  end

  get '/assessment/question_images/:question_id/:image_name' => 'quizzes#get_image_download_url'

  scope '/assessment' do
    scope '/apis' do
      get '/current_time' => 'api/v1/cengage#current_time'
      get '/assessment_types' => 'api/v1/cengage#assessment_types'
      get '/question_types' => 'api/v1/cengage#question_types'
      get '/difficulty_tags' => 'api/v1/cengage#difficulty_tags'
      get '/custom_tests' => 'api/v1/cengage#custom_tests'
      get '/published_tests' => 'api/v1/cengage#published_tests'
      get '/teacher_published_tests' => 'api/v1/cengage#teacher_published_tests'
      get '/grade_subjects_chapters_concepts' => 'api/v1/cengage#grade_subjects_chapters_concepts'
      post '/generate_quiz' => 'api/v1/cengage#generate_quiz'
      get '/get_quiz_json' => 'api/v1/cengage#get_quiz_json'
      get '/published_assessment_overview' => 'api/v1/cengage#published_assessment_overview'

      match '/get_question_json' => 'api/v1/cengage#get_question_json', via: [:get, :post]
      post '/publish_assessment' => 'api/v1/cengage#publish_assessment'

      match '/search_questions' => 'api/v1/cengage#search_questions', via: [:get, :post]
      post '/generate_quiz_by_question_ids' => 'api/v1/cengage#generate_quiz_by_question_ids'
      get '/get_quiz_params_for_duplication' => 'api/v1/cengage#get_quiz_params_for_duplication'
    end
  end

end
