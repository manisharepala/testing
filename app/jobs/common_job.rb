class CommonJob < ApplicationJob
  queue_as :assets

  def perform(id)
    # Do something later
    Quiz.find(id).upload_zip
  end
end
