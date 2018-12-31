Rails.application.routes.draw do
  post '/assessment/quiz_attempt_data', to: 'application#quiz_attempt_data'

  get "/assessment/zip_upload_question" => "quizzes#zip_upload_question"
  post "/assessment/post_zip_upload_question" => "quizzes#post_zip_upload_question"

  get '/assessment/get_quizzes', to: 'quizzes#get_quizzes'
  get '/assessment/get_quiz_for_browser', to: 'quizzes#get_quiz_for_browser'
  get '/assessment/get_quiz_for_app', to: 'quizzes#get_quiz_for_app'
end
