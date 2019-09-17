class QuizAttemptDataJob < ApplicationJob
  queue_as :quiz_attempt_data

  def perform(quiz_attempt_data)
    QuizAttemptData.find(quiz_attempt_data.id).process_quiz_attempt_data_delayed_job(quiz_attempt_data)
  end
end
