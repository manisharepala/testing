class AuthServer
  include HTTParty
  #base_uri ENV.fetch('AUTH_SERVER')
  base_uri '13.234.165.191'
  # base_uri '13.233.76.145'
  VERIFY_URL = '/users/validate_token'
  attr_reader :token, :data
  def initialize token
    @token = token
  end

  def valid?
    token_data = Rails.cache.fetch("auth_#{token}", expires_in: 1.hour) do
      res = self.class.get(VERIFY_URL, headers: headers)
      if res.success?
        {success: true, res_data: JSON.parse(res.body)}
      else
        {success: false}
      end
    end
    if token_data[:success]
      set_data token_data[:res_data]
      true
    else
      false
    end
    # res = self.class.get(VERIFY_URL, headers: headers)
    # if res.success?
    #   set_data JSON.parse(res.body)
    #   true
    # else
    #   false
    # end
  end

  def user_id
    data['user_id']
  end

  private
  def headers
    {token: token}
  end

  def set_data data
    @data = data
  end
end
