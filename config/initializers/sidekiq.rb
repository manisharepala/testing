options = {
  host: ENV['REDIS_SERVER'],
  port: ENV['REDIS_PORT'],
  db: ENV['REDIS_DB_SIDEKIQ'],
  password: ENV['REDIS_PASSWORD'],
  namespace: "sidekiq"
}
Sidekiq.configure_server do |config|
  config.redis = options
end

Sidekiq.configure_client do |config|
  config.redis = options
end
