class ApplicationController < ActionController::Base
  # protect_from_forgery except: [:quiz_attempt_data]
  before_action :authenticate_user!
  skip_before_action :verify_authenticity_token
  attr_reader :current_user


  def quiz_attempt_data
    records = params.to_unsafe_h[:data]
    if current_user.id == 48
      logger.info "-------------------------------------------------------------------------11111111111111111111111111----------------------------------------------"
      logger.info records
      logger.info "-------------------------------------------------------------------------11111111111111111111111111----------------------------------------------"
    end
    records.each {|r| QuizAttemptData.create!(data: r, user_id: current_user.id)}
    render json: {success: true}, status: 201
  end

  def multi_chapter_quiz_attempt_data
    records = params.to_unsafe_h[:data]
    records.each do |data|
      qad = QuizAttemptData.where("data.asset_download_id"=>{:$in=>[data['asset_download_id']]},user_id:current_user.id).last
      if qad.present?
        if qad.data['total_questions'].uniq == qad.data['attempted'].uniq
          QuizAttemptData.create!(data: data, user_id: current_user.id)
        else
          qad.data = data
          qad.save!
        end
      else
        QuizAttemptData.create!(data: data, user_id: current_user.id)
      end
    end
    render json: {success: true}, status: 201
  end


  private
  def authenticate_user!
    if get_token.nil?
      render json: {}, status: 401
      return
    end
    auth = AuthServer.new(get_token)
    if auth.valid?
      set_current_user(auth.data)
      store_token
      true
    else
      render json: {}, status: 401
      return
    end
  end

  def set_current_user(data)
    @current_user = User.new(data)
  end

  def get_token
    @token ||= (request.headers['token'] || params[:token] || request.headers['Authorization'].to_s.gsub('Bearer ', ''))
  end

  def store_token
    return nil if current_user.id.nil?
    Rails.cache.fetch(User.token_key(current_user.id), expires_in: 7.days) do
      get_token
    end
  end

end
