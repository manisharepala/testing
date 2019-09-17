class QuizAttemptDataJob < ApplicationJob
  queue_as :quiz_attempt_data

  def perform(id)
    QuizAttemptData.find(id).process_quiz_attempt_data_delayed_job
  end
end
