class User
  attr_reader :id, :data
  def initialize data
    # puts "data -- #{data}"
    @data = data
    @id = data['user_id']
  end

  def self.token_key(user_id)
    "user_token_#{user_id}"
  end

  def token
    self.class.get_token(id)
  end

  def self.get_token user_id
    if user_id == 12
      'eyJhbGciOiJIUzI1NiJ9.eyJ1c2VybmFtZSI6ImtyaXNobmExMiIsImVtYWlsIjpudWxsLCJyb2xsX25vIjpudWxsLCJ1c2VyX2lkIjoxMiwic3ViIjoiMTIiLCJzY3AiOiJ1c2VyIiwiYXVkIjpudWxsLCJpYXQiOjE1NDgwNjY3NDUsImV4cCI6MTU0ODE1MzE0NSwianRpIjoiZGFiNGI0MjQtMzQ0Ny00N2I1LWEwN2MtZjVhY2UxNzkyNjJkIn0.91Pl73VJqFR0lUPG30NqstOE0E1DVurCZK-JssNURtM'
    else
      Rails.cache.read(User.token_key(user_id))
    end
  end
end
