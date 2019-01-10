Rails.application.routes.draw do
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
  get '/assessment/get_quiz_for_browser', to: 'quizzes#get_quiz_for_browser'
  get '/assessment/get_quiz_for_app', to: 'quizzes#get_quiz_for_app'
end
