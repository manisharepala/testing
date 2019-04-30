class UserManagementServer
  include HTTParty
  base_uri '13.234.165.191'
  # base_uri 'localhost:4000'

  def self.get_group_details(group_id,token)
    # token = "eyJhbGciOiJIUzI1NiJ9.eyJ1c2VybmFtZSI6bnVsbCwiZW1haWwiOiJjbGFzc182X3RlYWNoZXJfMV8xNTUyOTkwOTU4X0B2YXJzaXR5LmNvbSIsInJvbGxfbm8iOm51bGwsInVzZXJfaWQiOjM2Mywic3ViIjoiMzYzIiwic2NwIjoidXNlciIsImF1ZCI6bnVsbCwiaWF0IjoxNTU2NTE1MDgyLCJleHAiOjE1NTY2MDE0ODIsImp0aSI6Ijk5YWJiYTFiLTAwNjMtNDg2My1hZWFhLWExM2M0ZWM5ZWEwNSJ9.PT0uU986H3XBAELUzWyp9CD1uLzvrUlSpPCsFaVqE3I"
    res = get("/user_management/apis/v1/get_group_details?group_id=#{group_id}&token=#{token}")
    res.success? ? JSON.parse(res.body) : false
  end

  def self.get_user_details(user_id,token)
    # token = "eyJhbGciOiJIUzI1NiJ9.eyJ1c2VybmFtZSI6bnVsbCwiZW1haWwiOiJjbGFzc182X3RlYWNoZXJfMV8xNTUyOTkwOTU4X0B2YXJzaXR5LmNvbSIsInJvbGxfbm8iOm51bGwsInVzZXJfaWQiOjM2Mywic3ViIjoiMzYzIiwic2NwIjoidXNlciIsImF1ZCI6bnVsbCwiaWF0IjoxNTU2NTE1MDgyLCJleHAiOjE1NTY2MDE0ODIsImp0aSI6Ijk5YWJiYTFiLTAwNjMtNDg2My1hZWFhLWExM2M0ZWM5ZWEwNSJ9.PT0uU986H3XBAELUzWyp9CD1uLzvrUlSpPCsFaVqE3I"
    res = get("/user_management/apis/v1/get_user_details?user_id=#{user_id}&token=#{token}")
    res.success? ? JSON.parse(res.body) : false
  end

end
