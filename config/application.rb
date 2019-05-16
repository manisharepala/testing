require File.expand_path('../boot', __FILE__)

require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module AssessmentApp
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 5.2

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    # config.time_zone = 'Central Time (US & Canada)'

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    # config.i18n.default_locale = :de

    # Do not swallow errors in after_commit/after_rollback callbacks.
    # config.active_record.raise_in_transactional_callbacks = true

    # cors enabling
    config.middleware.insert_before 0, Rack::Cors do
      allow do
        origins 'ec2-13-233-131-175.ap-south-1.compute.amazonaws.com','13.233.131.175','www.learnflix.in','ec2-13-126-51-248.ap-south-1.compute.amazonaws.com','learnflix.in','13.234.103.162','localhost:4000', '192.168.1.92:4000', 'ec2-13-250-46-76.ap-southeast-1.compute.amazonaws.com:4000', 'ec2-35-154-201-127.ap-south-1.compute.amazonaws.com:4000', '192.168.40.113:4000', '10.10.0.131:4000', 'ec2-52-66-236-230.ap-south-1.compute.amazonaws.com:4000','ec2-52-66-236-230.ap-south-1.compute.amazonaws.com','13.127.202.23:4000','13.127.202.23','ec2-13-127-138-219.ap-south-1.compute.amazonaws.com:4000','ec2-13-127-138-219.ap-south-1.compute.amazonaws.com','13.127.159.49'
        resource '*',
                 headers: :any,
                 expose: ['Authorization', 'ETag'],
                 methods: [:get, :post, :put, :patch, :delete, :options, :head],
                 credentials: true,
                 max_age: 86400
      end
    end


    config.assets.prefix = "/assessment/assets"

    config.autoload_paths += %w(#{config.root}/app/models/ckeditor)

    config.before_configuration do
      env_file = File.join(Rails.root, 'config', 'local_env.yml')
      YAML.load(File.open(env_file)).each do |key, value|
        ENV[key.to_s] = value
      end if File.exists?(env_file)
    end

  end
end
