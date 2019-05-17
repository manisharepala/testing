Rails.application.routes.draw do
  root 'quizzes#all_quizzes'

  mount Ckeditor::Engine => '/ckeditor'
  get '/assessment/ckeditor/pictures', to: 'ckeditor/pictures#index'
  post '/assessment/ckeditor/pictures', to: 'ckeditor/pictures#create'

  post '/assessment/quiz_attempt_data', to: 'application#quiz_attempt_data'
  post '/assessment/multi_chapter_quiz_attempt_data', to: 'application#multi_chapter_quiz_attempt_data'

  get "/assessment/zip_upload_question" => "quizzes#zip_upload_question"
  post "/assessment/post_zip_upload_question" => "quizzes#post_zip_upload_question"

  get "/assessment/migrate_quiz" => "quizzes#migrate_quiz"
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

  get '/assessment/get_focus_area', to: 'quizzes#get_focus_area'
  post '/assessment/update_focus_area', to: 'quizzes#update_focus_area'

  get '/assessment/quiz/edit', to: 'quizzes#quiz_edit'
  post '/assessment/quiz/update', to: 'quizzes#quiz_update'
  get '/assessment/quiz/delete', to: 'quizzes#quiz_delete'

  post '/assessment/get_quizzes_analytics_data', to: 'quizzes#get_quizzes_analytics_data'
  post '/assessment/get_chapter_level_quizzes_analytics_data', to: 'quizzes#get_chapter_level_quizzes_analytics_data'
  post '/assessment/get_concept_wise_quizzes_analytics_data', to: 'quizzes#get_concept_wise_quizzes_analytics_data'
  post '/assessment/get_assessments_attempted_count', to: 'quizzes#get_assessments_attempted_count'
  post '/assessment/get_are_assessments_attempted', to: 'quizzes#get_are_assessments_attempted'
  post '/assessment/get_assessments_active_duration', to: 'quizzes#get_assessments_active_duration'
  post '/assessment/get_assessments_attempt_data', to: 'quizzes#get_assessments_attempt_data'
  get '/assessment/get_book_assessments_attempted/:book_id/:user_id', to: 'quizzes#get_book_assessments_attempted'

  get '/assessment/get_quiz_attempt_data', to: 'quizzes#get_quiz_attempt_data'
  get '/assessment/get_multi_chapter_quiz_attempt_data', to: 'quizzes#get_multi_chapter_quiz_attempt_data'

#teacher web api's
  get '/assessment/user_assessments_by_category', to: 'api#user_assessments_by_category'
  post '/assessment/edit_due_time', to: 'api#edit_due_time'
  post '/assessment/cancel_published_assessment', to: 'api#cancel_published_assessment'
  post '/assessment/publish_assessment', to: 'api#publish_assessment'

  get '/assessment/different_question_types_by_marks', to: 'api#different_question_types_by_marks'
  get '/assessment/different_question_types_by_difficulty', to: 'api#different_question_types_by_difficulty'


  get '/assessment/assessment_details', to: 'api#assessment_details'
  get '/assessment/user_tags_by_category', to: 'api#user_tags_by_category'
  post '/assessment/create_duplicate_assessment', to: 'api#create_duplicate_assessment'

  post 'get_child_tags', to: 'tags#get_child_tags'
  get '/update_question_tags', to: 'tags#update_question_tags'

end
