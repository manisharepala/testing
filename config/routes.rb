Rails.application.routes.draw do
  root 'quizzes#all_quizzes'

  mount Ckeditor::Engine => '/ckeditor'
  post '/assessment/quiz_attempt_data', to: 'application#quiz_attempt_data'

  get "/assessment/zip_upload_question" => "quizzes#zip_upload_question"
  post "/assessment/post_zip_upload_question" => "quizzes#post_zip_upload_question"

  get '/assessment/all_quizzes', to: 'quizzes#all_quizzes'
  get '/assessment/quiz_questions', to: 'quizzes#quiz_questions'
  get '/assessment/question/show', to: 'questions#show'
  get '/assessment/question/edit', to: 'questions#edit'
  post '/assessment/question/update', to: 'questions#update'

  get '/assessment/get_quizzes', to: 'quizzes#get_quizzes'
  get '/assessment/get_quiz_json', to: 'quizzes#get_quiz_json'

  get '/assessment/get_focus_area', to: 'quizzes#get_focus_area'
  post '/assessment/update_focus_area', to: 'quizzes#update_focus_area'

  get '/assessment/quiz/edit', to: 'quizzes#quiz_edit'
  post '/assessment/quiz/update', to: 'quizzes#quiz_update'

  post '/assessment/get_quizzes_analytics_data', to: 'quizzes#get_quizzes_analytics_data'
  post '/assessment/get_chapter_level_quizzes_analytics_data', to: 'quizzes#get_chapter_level_quizzes_analytics_data'
  post '/assessment/get_concept_wise_quizzes_analytics_data', to: 'quizzes#get_concept_wise_quizzes_analytics_data'
  post '/assessment/get_assessments_attempted_count', to: 'quizzes#get_assessments_attempted_count'
  post '/assessment/get_assessments_active_duration', to: 'quizzes#get_assessments_active_duration'

  get '/assessment/get_quiz_attempt_data', to: 'quizzes#get_quiz_attempt_data'

#teacher web api's
  # get '/assessment/user_assessments_by_category', to: 'api#user_assessments_by_category'
  # post '/assessment/edit_due_time', to: 'api#edit_due_time'
  # post '/assessment/cancel_published_assessment', to: 'api#cancel_published_assessment'
  # post '/assessment/publish_assessment', to: 'api#publish_assessment'
  # get '/assessment/assessment_details', to: 'api#assessment_details'
  # get '/assessment/user_tags_by_category', to: 'api#user_tags_by_category'
  # post '/assessment/create_duplicate_assessment', to: 'api#create_duplicate_assessment'

end
