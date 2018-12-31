

TagsDb.find_or_create_by(name: 'TagsDb1')
Tag.find_or_create_by(name: 'subject', value: 'Maths', tags_db_id: TagsDb.first._id)
Tag.find_or_create_by(name: 'academic_class', value: '9', tags_db_id: TagsDb.first._id)

PublisherQuestionBank.create!(name: 'QB1', description: 'QB!', publisher_id: 1)
qb_ids = [PublisherQuestionBank.first._id]
tag_ids = Tag.pluck(:id).map(&:to_s)
smcq_data = {questiontext: '2 + 3', generalfeedback: 'abc', hint: 'abc', 'qtype'=> 'SmcqQuestion', created_by: 23, publisher_question_bank_ids: qb_ids, tag_ids: tag_ids, question_answers_attributes: [{answer: '5', fraction: true}, {answer: '1234', fraction: false}, {answer: '1243', fraction: false}, {answer: '1423', fraction: false}] }

mmcq_data = {questiontext: ' 5 > ?', 'qtype'=> 'MmcqQuestion', created_by: 23, publisher_question_bank_ids: qb_ids, tag_ids: tag_ids, question_answers_attributes: [{answer: '4', fraction: true}, {answer: '3', fraction: true}, {answer: '1243', fraction: false}, {answer: '1423', fraction: false}] }

true_false_data = {questiontext: '2 + 3 = 5', 'qtype'=> 'TrueFalseQuestion', created_by: 23, publisher_question_bank_ids: qb_ids, tag_ids: tag_ids, question_answers_attributes: [{answer: 'True', fraction: true}, {answer: 'False', fraction: false}] }

fib_data = {questiontext: '2 + 3 = #DASH# and 5 + 7 = #DASH#', 'qtype'=> 'FibQuestion', created_by: 23, publisher_question_bank_ids: qb_ids, tag_ids: tag_ids, question_fill_blanks_attributes: [{answer: '5'}, {answer: ' 12'}] }

Question.create_question(smcq_data)
Question.create_question(mmcq_data)
Question.create_question(true_false_data)
Question.create_question(fib_data)

quiz_targeted_group_data = {password:'4123', time_open:(Time.now.to_i), time_close:(Time.now.to_i+1.year.to_i), show_score_after:100, show_answers_after:100, published_by:1, group_id:2, message_subject:'Quiz publish subject', message_body:'quiz publish body'}
QuizTargetedGroup.create_quiz_targeted_group(quiz_targeted_group_data)


question_ids = Question.pluck(:id).map(&:to_s).first(4)

quiz_data = {name:'Quiz1', description: 'Quiz with out sections', instructions:'Attempt all Questions', total_marks: 100, total_time: 180, created_by:1, tag_ids:tag_ids, question_ids:question_ids}
quiz1 = Quiz.create_quiz(quiz_data)
quiz1.quiz_targeted_groups_attributes = [{password:'4123', time_open:(Time.now.to_i), time_close:(Time.now.to_i+1.year.to_i), show_score_after:100, show_answers_after:100, published_by:1, group_id:2, message_subject:'Quiz publish subject', message_body:'quiz publish body'}]
quiz1.save


quiz_data_with_sections = {name:'Quiz2', description: 'Quiz with sections', instructions:'Attempt all Questions', total_marks: 100, total_time: 180, created_by:1, tag_ids:tag_ids}
quiz2 = Quiz.create_quiz(quiz_data_with_sections)

quiz2.quiz_sections_attributes = [{name:'Quiz Section 1', instructions:'Quiz section instructions 1'}, {name:'Quiz secction 2', instructions:'Quiz section instructions 2'}]
quiz2.save

quiz2.quiz_sections_attributes = [{name:'Quiz secction 3', instructions:'Quiz section instructions 3'}]

quiz2.attributes = {quiz_sections_attributes: [{name:'Quiz secction 4', instructions:'Quiz section instructions 4'}]}
quiz2.save

Question.each do |q|
  QuizQuestionInstance.create(marks:q.defaultmark, penalty:q.penalty,question_id:q.id, quiz_id:Quiz.pluck(:id).map(&:to_s)[1], quiz_section_id:QuizSection.pluck(:id).map(&:to_s)[0])
end

#S3Configuration.create(region: "ap-southeast-1", access_key_id:"AKIAIYVXJZRUR5UU6QTQ",secret_access_key:"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",bucket_name:"learnflix-question-images")
# UsersS3Configuration.create(user_id:1,s3_configuration_id:1)





