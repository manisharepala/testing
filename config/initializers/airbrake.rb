Airbrake.configure do |config|
  config.host = 'http://localhost:3000'
  config.project_id = 1 # required, but any positive integer works
  config.project_key = '6ad0fbae9314b310950cf7426b8118ea'
  config.performance_stats = false

  # Uncomment for Rails apps
  # config.environment = Rails.env
  # config.ignore_environments = %w(development test)
end
