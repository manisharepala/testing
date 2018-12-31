class ApplicationController < ActionController::Base
  # protect_from_forgery except: [:quiz_attempt_data]
  skip_before_action :verify_authenticity_token
  def quiz_attempt_data
    records = params.to_unsafe_h[:data]
    records.each {|r| QuizAttemptData.create!(data: r)}
    render json: {success: true}, status: 201
  end
end
