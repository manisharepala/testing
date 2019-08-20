class CommonJob < ApplicationJob
  queue_as :default

  def perform(id)
    # Do something later
    Quiz.find(id).upload_zip
  end
end
