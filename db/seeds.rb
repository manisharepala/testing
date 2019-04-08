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

# q = Question.find('5c24a323957966371e3b6e1a')
# Image.create(key:"/question_images/5c24a323957966371e3b6e1a/image003.jpg", name:"image001.jpg", file_path:"/home/inayath/edutor/assessment_app/public/question_images/5c24a323957966371e3b6e1a/image001.jpg")


#PassageQuestion
qb_ids = [PublisherQuestionBank.first._id]
tag_ids = Tag.pluck(:id).map(&:to_s)
smcq_data = {questiontext: '2 + 3',default_mark:1,penalty:0, generalfeedback: 'abc', hint: 'abc', 'qtype'=> 'SmcqQuestion', created_by: 23, publisher_question_bank_ids: qb_ids, tag_ids: tag_ids, question_answers_attributes: [{answer: '5', fraction: true}, {answer: '1234', fraction: false}, {answer: '1243', fraction: false}, {answer: '1423', fraction: false}] }

mmcq_data = {questiontext: ' 5 > ?',default_mark:1,penalty:0, 'qtype'=> 'MmcqQuestion', created_by: 23, publisher_question_bank_ids: qb_ids, tag_ids: tag_ids, question_answers_attributes: [{answer: '4', fraction: true}, {answer: '3', fraction: true}, {answer: '1243', fraction: false}, {answer: '1423', fraction: false}] }

true_false_data = {questiontext: '2 + 3 = 5',default_mark:1,penalty:0, 'qtype'=> 'TrueFalseQuestion', created_by: 23, publisher_question_bank_ids: qb_ids, tag_ids: tag_ids, question_answers_attributes: [{answer: 'True', fraction: true}, {answer: 'False', fraction: false}] }

fib_data = {questiontext: '2 + 3 = #DASH# and 5 + 7 = #DASH#',default_mark:1,penalty:0, 'qtype'=> 'FibQuestion', created_by: 23, publisher_question_bank_ids: qb_ids, tag_ids: tag_ids, question_fill_blanks_attributes: [{answer: '5'}, {answer: ' 12'}] }

passage_data = {questiontext: 'Answer below questions based on the following paragraph \n Time is precious and valuable',default_mark:4,penalty:0, generalfeedback: 'solution if there', hint: 'hint to understand paragraph', 'qtype'=> 'PassageQuestion', created_by: 23, publisher_question_bank_ids: qb_ids, tag_ids: tag_ids, question_guids: ["01d47b1d-45a2-48fe-b078-5599eca9ee00", "0b75ca37-294b-46fc-bb79-e62dd79cdd5e", "6f97dee5-85d0-48c4-b088-de1c6bb03480", "7d4fbf97-8b19-4ec7-b83c-5b92ee015c66"] }

pq = Question.create_question(passage_data)

integer_data = {questiontext: 'Answer below questions based on the following paragraph \n Time is precious and valuable',default_mark:4,penalty:0, generalfeedback: 'solution if there', hint: 'hint to understand paragraph', 'qtype'=> 'IntegerQuestion', created_by: 23, publisher_question_bank_ids: qb_ids, tag_ids: tag_ids, no_of_digits:2}

i = Question.create_question(integer_data)

qb_ids = [PublisherQuestionBank.first._id]
tag_ids = Tag.pluck(:id).map(&:to_s)
matrix_data = {questiontext: 'Match both columns',default_mark:4,penalty:0, generalfeedback: 'solution if there', hint: 'hint to understand paragraph', 'qtype'=> 'MatrixQuestion', created_by: 23, publisher_question_bank_ids: qb_ids, tag_ids: tag_ids, question_statements_attributes: [{statement: 'match header 1'},{statement: 'match header 2'},{statement: 'match header 3'},{statement: 'match header 4'}], question_answers_attributes: [{answer: 'match option 1'}, {answer: 'match option 2'}, {answer: 'match option 3'}, {answer: 'match option 4'}] }

m = Question.create_question(matrix_data) #"ca0a876c-4633-4e49-b9ca-046ae7986236"

qa_ids = m.question_answers.map(&:id)
m.question_statements.each_with_index do |qt,i|
  qt.question_answer_ids << qa_ids[i].to_s
  qt.question_answer_ids << qa_ids[i-1].to_s
  qt.save!
end

#fib int

fib_integer_data = {questiontext: '2 + 3 = #DASH# and 5 + 7 = #DASH#',default_mark:1,penalty:0, 'qtype'=> 'FibIntegerQuestion', created_by: 23, publisher_question_bank_ids: qb_ids, tag_ids: tag_ids, question_fill_blanks_attributes: [{answer: '5.12'}, {answer: '12.25'}] }

fi = Question.create_question(fib_integer_data)

#mcq_matrix
mcq_matrix_data = {questiontext: '2 + 3',default_mark:1,penalty:0, generalfeedback: 'abc', hint: 'abc', 'qtype'=> 'McqMatrixQuestion', created_by: 23, publisher_question_bank_ids: qb_ids, tag_ids: tag_ids, question_answers_attributes: [{answer: 'p->5;q->1,2;r->1;s->1,4;', fraction: true}, {answer: 'p->1,5;q->1,2,3;r->1;s->1,3;', fraction: false}, {answer: 'p->2,5;q->1,3;r->1;s->1,4;', fraction: false}, {answer: 'p->2,4;q->1,2;r->1;s->1,4;', fraction: false}] }

mm = Question.create_question(mcq_matrix_data)

sq = SmcqQuestion.last
mq = MmcqQuestion.last
fq = FibQuestion.last
fiq = FibIntegerQuestion.last
tq = TrueFalseQuestion.last
pq = PassageQuestion.last
mmq = McqMatrixQuestion.last

s1q = SubjectiveQuestion.last
# iq = IntegerQuestion.last
# m1q = MatrixQuestion.last



question_ids = [sq.id.to_s,mq.id.to_s,fq.id.to_s,fiq.id.to_s,tq.id.to_s,pq.id.to_s,mmq.id.to_s] #["5c80dfe495796611e8dc1060", "5c514159957966120abac6f3", "5c51415b957966120abac6f5", "5c346edb9579663271b2bb50", "5c5ac4d39579663c11b0d96b", "5c80e840957966208edc105c", "5c80eb42957966208edc105d", "5c82116c9579661abff48199"]

total_marks = question_ids.map{|id| Question.find(id).default_mark}.sum
quiz = Quiz.create(name:'All questions quiz',question_ids:question_ids, type:'tryout', player:'tryout', total_marks:total_marks)
quiz.key = "/quiz_zips/#{quiz.guid}.zip"
quiz.file_path = Rails.root.to_s + "/public/quiz_zips/#{quiz.guid}.zip"
quiz.save! #"818cd91f-17b1-4d28-8fcc-e3c80d63dea8"

#######################################
qb_ids = [PublisherQuestionBank.first._id]
tag_ids = Tag.pluck(:id).map(&:to_s)

smcq_data = {question_language_specific_datas_attributes: [{question_text: 'Smcq Question in English',general_feedback:'Solution in english', hint:'hint in english',actual_answer:'Answer in english', language: 'english'}, {question_text: 'Smcq Question in Hindi',general_feedback:'Solution in hindi', hint:'hint in hindi',actual_answer:'Answer in hindi', language: 'hindi'}],default_mark:1,penalty:0, 'qtype'=> 'SmcqQuestion','display_q_type'=> 'SmcqQuestion', created_by: 23, publisher_question_bank_ids: qb_ids, tag_ids: tag_ids, question_answers_attributes: [{answer_english: 'Option 1 English',answer_hindi: 'Option 1 Hindi', fraction: true}, {answer_english: 'Option 2 English',answer_hindi: 'Option 2 Hindi', fraction: false}, {answer_english: 'Option 3 English',answer_hindi: 'Option 3 Hindi', fraction: false}, {answer_english: 'Option 4 English',answer_hindi: 'Option 4 Hindi', fraction: false}]}

sq = Question.create_question(smcq_data) # sq = Question.where(guid:"5cd83d3c-a0f0-44d1-a2a1-20a18b7299fa")[0]
d = sq.as_json(with_key:true)

mmcq_data = {question_language_specific_datas_attributes: [{question_text: 'Mmcq Question in English',general_feedback:'Solution in english', hint:'hint in english',actual_answer:'Answer in english', language: 'english'}, {question_text: 'Mmcq Question in Hindi',general_feedback:'Solution in hindi', hint:'hint in hindi',actual_answer:'Answer in hindi', language: 'hindi'}],default_mark:1,penalty:0, 'qtype'=> 'MmcqQuestion', 'display_q_type'=> 'MmcqQuestion',created_by: 23, publisher_question_bank_ids: qb_ids, tag_ids: tag_ids, question_answers_attributes: [{answer_english: 'Option 1 English',answer_hindi: 'Option 1 Hindi', fraction: true}, {answer_english: 'Option 2 English',answer_hindi: 'Option 2 Hindi', fraction: true}, {answer_english: 'Option 3 English',answer_hindi: 'Option 3 Hindi', fraction: false}, {answer_english: 'Option 4 English',answer_hindi: 'Option 4 Hindi', fraction: false}]}

mq = Question.create_question(mmcq_data) # mq = Question.where(guid:"d2fc59a6-f59b-437b-bdaf-61be12ac7b81")[0]
d = mq.as_json(with_key:true)

#mcq_matrix
mcq_matrix_data = {question_language_specific_datas_attributes: [{question_text: 'Matrix Question in English',general_feedback:'Solution in english', hint:'hint in english',actual_answer:'Answer in english', language: 'english'}, {question_text: 'Matrix Question in Hindi',general_feedback:'Solution in hindi', hint:'hint in hindi',actual_answer:'Answer in hindi', language: 'hindi'}],default_mark:1,penalty:0, 'qtype'=> 'McqMatrixQuestion','display_q_type'=> 'MatrixQuestion', created_by: 23, publisher_question_bank_ids: qb_ids, tag_ids: tag_ids, question_answers_attributes: [{answer_english: 'English: p->5;q->1,2;r->1;s->1,4;',answer_hindi: 'Hindi: p->5;q->1,2;r->1;s->1,4;', fraction: true}, {answer_english: 'English: p->1,5;q->1,2,3;r->1;s->1,3;',answer_hindi: 'Hindi: p->1,5;q->1,2,3;r->1;s->1,3;', fraction: false}, {answer_english: 'English: p->2,5;q->1,3;r->1;s->1,4;',answer_hindi: 'Hindi: p->2,5;q->1,3;r->1;s->1,4;', fraction: false}, {answer_english: 'English:p->2,4;q->1,2;r->1;s->1,4;',answer_hindi: 'Hindi: p->2,4;q->1,2;r->1;s->1,4;', fraction: false}]}

mm = Question.create_question(mcq_matrix_data) # mm = Question.where(guid:"afce484a-28ce-4993-8bd4-0869b3caa897")[0]
d = mm.as_json(with_key:true)

#assertion_reason_question
assertion_reason_data = {question_language_specific_datas_attributes: [{question_text: 'AssertionReasonQuestion in English',general_feedback:'Solution in english', hint:'hint in english',actual_answer:'Answer in english', language: 'english'}, {question_text: 'AssertionReasonQuestion in Hindi',general_feedback:'Solution in hindi', hint:'hint in hindi',actual_answer:'Answer in hindi', language: 'hindi'}],default_mark:1,penalty:0, 'qtype'=> 'AssertionReasonQuestion','display_q_type'=> 'AssertionReasonQuestion', created_by: 23, publisher_question_bank_ids: qb_ids, tag_ids: tag_ids, question_answers_attributes: [{answer_english: 'English: Statement-1 is True, Statement-2 is True; Statement-2 is the correct explanation of Statement-1.',answer_hindi: 'Hindi: Statement-1 is True, Statement-2 is True; Statement-2 is the correct explanation of
Statement-1.', fraction: true}, {answer_english: 'English: Statement-1 is True, Statement-2 is True; Statement-2 is not a correct explanation of Statement-1.',answer_hindi: 'Hindi: Statement-1 is True, Statement-2 is True; Statement-2 is not a correct explanation of Statement-1.', fraction: false}, {answer_english: 'English: Statement-1 is True, Statement-2 is False',answer_hindi: 'Hindi: Statement-1 is True, Statement-2 is False', fraction: false}, {answer_english: 'English:Statement-1 is False, Statement-2 is True.',answer_hindi: 'Hindi: Statement-1 is False, Statement-2 is True.', fraction: false}]}

aq = Question.create_question(assertion_reason_data) # aq = Question.where(guid:"4cfab597-4f57-426d-b61b-37e8cf0276e9")[0]
d = aq.as_json(with_key:true)

true_false_data = {question_language_specific_datas_attributes: [{question_text: 'ToF Question in English',general_feedback:'Solution in english', hint:'hint in english',actual_answer:'Answer in english', language: 'english'}, {question_text: 'ToF Question in Hindi',general_feedback:'Solution in hindi', hint:'hint in hindi',actual_answer:'Answer in hindi', language: 'hindi'}],default_mark:1,penalty:0, 'qtype'=> 'TrueFalseQuestion','display_q_type'=> 'TrueFalseQuestion', created_by: 23, publisher_question_bank_ids: qb_ids, tag_ids: tag_ids, question_answers_attributes: [{answer_english: 'True',answer_hindi: 'True in Hindi', fraction: true}, {answer_english: 'False',answer_hindi: 'False in Hindi', fraction: false}]}

tq = Question.create_question(true_false_data) # tq = Question.where(guid:"d5a6e3c9-03e7-40c6-9741-cff3636c5962")[0]
d = tq.as_json(with_key:true)

fib_data = {question_language_specific_datas_attributes: [{question_text: 'ToF Question in English: 2 + 3 = #DASH# and 5 + 7 = #DASH#',general_feedback:'Solution in english', hint:'hint in english',actual_answer:'Answer in english', language: 'english'}, {question_text: 'ToF Question in Hindi: 2 + 3 = #DASH# and 5 + 7 = #DASH#',general_feedback:'Solution in hindi', hint:'hint in hindi',actual_answer:'Answer in hindi', language: 'hindi'}],default_mark:1,penalty:0, 'qtype'=> 'FibQuestion','display_q_type'=> 'FibQuestion', created_by: 23, publisher_question_bank_ids: qb_ids, tag_ids: tag_ids, question_fill_blanks_attributes: [{answer: ['five',5]}, {answer: ['12', 'twelve']}]}

fq = Question.create_question(fib_data) # fq = Question.where(guid:"b212a554-d92f-44df-9d0f-e3b99afe32a8")[0]
d = fq.as_json(with_key:true)

#fib int

fib_integer_data = {question_language_specific_datas_attributes: [{question_text: 'ToF Question in English: 2 + 3 = #DASH# and 5 + 7 = #DASH#',general_feedback:'Solution in english', hint:'hint in english',actual_answer:'Answer in english', language: 'english'}, {question_text: 'ToF Question in Hindi: 2 + 3 = #DASH# and 5 + 7 = #DASH#',general_feedback:'Solution in hindi', hint:'hint in hindi',actual_answer:'Answer in hindi', language: 'hindi'}],default_mark:1,penalty:0, 'qtype'=> 'FibIntegerQuestion','display_q_type'=> 'IntegerQuestion', created_by: 23, publisher_question_bank_ids: qb_ids, tag_ids: tag_ids, question_fill_blanks_attributes: [{answer: [5.12,5.10]}, {answer: [12.30,12.25]}] }

fi = Question.create_question(fib_integer_data) # fi = Question.where(guid:"a624b44f-d8f0-419d-a532-886bddbb5998")[0]
d = fi.as_json(with_key:true)

passage_data = {question_language_specific_datas_attributes: [{question_text: 'Passage Question in English',general_feedback:'Solution in english', hint:'hint in english',actual_answer:'Answer in english', language: 'english'}, {question_text: 'Passage Question in Hindi',general_feedback:'Solution in hindi', hint:'hint in hindi',actual_answer:'Answer in hindi', language: 'hindi'}],default_mark:4,penalty:0, 'qtype'=> 'PassageQuestion','display_q_type'=> 'PassageQuestion', created_by: 23, publisher_question_bank_ids: qb_ids, tag_ids: tag_ids, question_guids: ["5cd83d3c-a0f0-44d1-a2a1-20a18b7299fa","d2fc59a6-f59b-437b-bdaf-61be12ac7b81","afce484a-28ce-4993-8bd4-0869b3caa897"] }

pq = Question.create_question(passage_data) # pq = Question.where(guid:"cbb519f5-29e4-4aeb-9b9e-ad135985bfd4")[0]
d = pq.as_json(with_key:true)


sq = Question.where(guid:"5cd83d3c-a0f0-44d1-a2a1-20a18b7299fa")[0]
mq = Question.where(guid:"d2fc59a6-f59b-437b-bdaf-61be12ac7b81")[0]
mm = Question.where(guid:"afce484a-28ce-4993-8bd4-0869b3caa897")[0]
aq = Question.where(guid:"4cfab597-4f57-426d-b61b-37e8cf0276e9")[0]
tq = Question.where(guid:"d5a6e3c9-03e7-40c6-9741-cff3636c5962")[0]
fq = Question.where(guid:"b212a554-d92f-44df-9d0f-e3b99afe32a8")[0]
fi = Question.where(guid:"a624b44f-d8f0-419d-a532-886bddbb5998")[0]
pq = Question.where(guid:"cbb519f5-29e4-4aeb-9b9e-ad135985bfd4")[0]


question_ids_1 = [sq.id.to_s,mq.id.to_s]
question_ids_2 = [fq.id.to_s,fi.id.to_s,tq.id.to_s]
question_ids_3 = [pq.id.to_s,mm.id.to_s, aq.id.to_s]

quiz_section_1 = QuizSection.find("5c84efba95796631967205d5")
quiz_section_2 = QuizSection.find("5c84efdd95796631967205d8")
quiz_section_3 = QuizSection.find("5c84efdd95796631967205db")

total_marks = [question_ids_1+question_ids_2+question_ids_3].flatten.map{|id| Question.find(id).default_mark}.sum
quiz = Quiz.create(type:'chapter_test_objective', player:'chapter_test_objective', total_marks:total_marks, total_time:180, quiz_language_specific_datas_attributes: [{name:'Quiz name in english',description: 'description in English',instructions:'instructions in english', language: 'english'}, {name:'Quiz name in hindi',description: 'description in Hindi',instructions:'instructions in hindi', language: 'hindi'}])

quiz = Quiz.find("5c84f12695796631967205de")
{"name"=>{"english"=>"Quiz name in english", "hindi"=>"Quiz name in hindi"}, "description"=>{"english"=>"description in English", "hindi"=>"description in Hindi"}, "instructions"=>{"english"=>"instructions in english", "hindi"=>"instructions in hindi"}, "total_marks"=>11.0, "total_time"=>180, "player"=>"chapter_test_objective", "languages_supported"=>["english", "hindi"], "questions"=>[{"id"=>"5c828b959579661ab17f86c7", "question_text"=>{"english"=>"Smcq Question in English", "hindi"=>"Smcq Question in Hindi"}, "marks"=>1.0, "penalty"=>0.0, "partial_positive_marks"=>0.0, "partial_negative_marks"=>0.0, "question_type"=>"SmcqQuestion", "tags"=>[], "explanation"=>{"english"=>"Solution in english", "hindi"=>"Solution in hindi"}, "hint"=>{"english"=>"hint in english", "hindi"=>"hint in hindi"}, "actual_answer"=>{"english"=>"Answer in english", "hindi"=>"Answer in hindi"}, "options"=>[{"id"=>"5c828b959579661ab17f86c3", "fraction"=>true, "answer"=>{"english"=>"Option 1 English", "hindi"=>"Option 1 Hindi"}}, {"id"=>"5c828b959579661ab17f86c4", "fraction"=>false, "answer"=>{"english"=>"Option 2 English", "hindi"=>"Option 2 Hindi"}}, {"id"=>"5c828b959579661ab17f86c5", "fraction"=>false, "answer"=>{"english"=>"Option 3 English", "hindi"=>"Option 3 Hindi"}}, {"id"=>"5c828b959579661ab17f86c6", "fraction"=>false, "answer"=>{"english"=>"Option 4 English", "hindi"=>"Option 4 Hindi"}}], "answers"=>[["5c828b959579661ab17f86c3"]], "blanks"=>[]}, {"id"=>"5c828c509579661ab17f86ce", "question_text"=>{"english"=>"Mmcq Question in English", "hindi"=>"Mmcq Question in Hindi"}, "marks"=>1.0, "penalty"=>0.0, "partial_positive_marks"=>0.0, "partial_negative_marks"=>0.0, "question_type"=>"MmcqQuestion", "tags"=>[], "explaination"=>{"english"=>"Solution in english", "hindi"=>"Solution in hindi"}, "hint"=>{"english"=>"hint in english", "hindi"=>"hint in hindi"}, "actual_answer"=>{"english"=>"Answer in english", "hindi"=>"Answer in hindi"}, "options"=>[{"id"=>"5c828c509579661ab17f86ca", "fraction"=>true, "answer"=>{"english"=>"Option 1 English", "hindi"=>"Option 1 Hindi"}}, {"id"=>"5c828c509579661ab17f86cb", "fraction"=>true, "answer"=>{"english"=>"Option 2 English", "hindi"=>"Option 2 Hindi"}}, {"id"=>"5c828c509579661ab17f86cc", "fraction"=>false, "answer"=>{"english"=>"Option 3 English", "hindi"=>"Option 3 Hindi"}}, {"id"=>"5c828c509579661ab17f86cd", "fraction"=>false, "answer"=>{"english"=>"Option 4 English", "hindi"=>"Option 4 Hindi"}}], "answers"=>[["5c828c509579661ab17f86ca", "5c828c509579661ab17f86cb"]], "blanks"=>[]}, {"id"=>"5c828de79579661b5c7f86c5", "question_text"=>{"english"=>"ToF Question in English: 2 + 3 = #DASH# and 5 + 7 = #DASH#", "hindi"=>"ToF Question in Hindi: 2 + 3 = #DASH# and 5 + 7 = #DASH#"}, "marks"=>1.0, "penalty"=>0.0, "partial_positive_marks"=>0.0, "partial_negative_marks"=>0.0, "question_type"=>"FibQuestion", "tags"=>[], "explaination"=>{"english"=>"Solution in english", "hindi"=>"Solution in hindi"}, "hint"=>{"english"=>"hint in english", "hindi"=>"hint in hindi"}, "actual_answer"=>{"english"=>"Answer in english", "hindi"=>"Answer in hindi"}, "blanks"=>[{"id"=>"5c828de79579661b5c7f86c3", "answer"=>["five", 5], "case_sensitive"=>false}, {"id"=>"5c828de79579661b5c7f86c4", "answer"=>["12", "twelve"], "case_sensitive"=>false}]}, {"id"=>"5c828e969579661b9f7f86c5", "question_text"=>{"english"=>"ToF Question in English: 2 + 3 = #DASH# and 5 + 7 = #DASH#", "hindi"=>"ToF Question in Hindi: 2 + 3 = #DASH# and 5 + 7 = #DASH#"}, "marks"=>1.0, "penalty"=>0.0, "partial_positive_marks"=>0.0, "partial_negative_marks"=>0.0, "question_type"=>"FibIntegerQuestion", "tags"=>[], "explaination"=>{"english"=>"Solution in english", "hindi"=>"Solution in hindi"}, "hint"=>{"english"=>"hint in english", "hindi"=>"hint in hindi"}, "actual_answer"=>{"english"=>"Answer in english", "hindi"=>"Answer in hindi"}, "blanks"=>[{"id"=>"5c828e969579661b9f7f86c3", "answer"=>[5.12, 5.1], "case_sensitive"=>false}, {"id"=>"5c828e969579661b9f7f86c4", "answer"=>[12.3, 12.25], "case_sensitive"=>false}], "no_of_int_digits"=>2, "no_of_decimal_digits"=>2}, {"id"=>"5c828d5a9579661ab17f86e1", "question_text"=>{"english"=>"ToF Question in English", "hindi"=>"ToF Question in Hindi"}, "marks"=>1.0, "penalty"=>0.0, "partial_positive_marks"=>0.0, "partial_negative_marks"=>0.0, "question_type"=>"TrueFalseQuestion", "tags"=>[], "explaination"=>{"english"=>"Solution in english", "hindi"=>"Solution in hindi"}, "hint"=>{"english"=>"hint in english", "hindi"=>"hint in hindi"}, "actual_answer"=>{"english"=>"Answer in english", "hindi"=>"Answer in hindi"}, "options"=>[{"id"=>"5c828d5a9579661ab17f86df", "fraction"=>true, "answer"=>{"english"=>"True", "hindi"=>"True in Hindi"}}, {"id"=>"5c828d5a9579661ab17f86e0", "fraction"=>false, "answer"=>{"english"=>"False", "hindi"=>"False in Hindi"}}], "answers"=>[["5c828d5a9579661ab17f86df"]], "blanks"=>[]}, {"id"=>"5c828f009579661b9f7f86c8", "question_text"=>{"english"=>"Passage Question in English", "hindi"=>"Passage Question in Hindi"}, "marks"=>4.0, "penalty"=>0.0, "partial_positive_marks"=>0.0, "partial_negative_marks"=>0.0, "question_type"=>"PassageQuestion", "tags"=>[], "explaination"=>{"english"=>"Solution in english", "hindi"=>"Solution in hindi"}, "hint"=>{"english"=>"hint in english", "hindi"=>"hint in hindi"}, "actual_answer"=>{"english"=>"Answer in english", "hindi"=>"Answer in hindi"}, "questions"=>[{"id"=>"5c828b959579661ab17f86c7", "question_text"=>{"english"=>"Smcq Question in English", "hindi"=>"Smcq Question in Hindi"}, "marks"=>1.0, "penalty"=>0.0, "partial_positive_marks"=>0.0, "partial_negative_marks"=>0.0, "question_type"=>"SmcqQuestion", "tags"=>[], "explaination"=>{"english"=>"Solution in english", "hindi"=>"Solution in hindi"}, "hint"=>{"english"=>"hint in english", "hindi"=>"hint in hindi"}, "actual_answer"=>{"english"=>"Answer in english", "hindi"=>"Answer in hindi"}, "options"=>[{"id"=>"5c828b959579661ab17f86c3", "fraction"=>true, "answer"=>{"english"=>"Option 1 English", "hindi"=>"Option 1 Hindi"}}, {"id"=>"5c828b959579661ab17f86c4", "fraction"=>false, "answer"=>{"english"=>"Option 2 English", "hindi"=>"Option 2 Hindi"}}, {"id"=>"5c828b959579661ab17f86c5", "fraction"=>false, "answer"=>{"english"=>"Option 3 English", "hindi"=>"Option 3 Hindi"}}, {"id"=>"5c828b959579661ab17f86c6", "fraction"=>false, "answer"=>{"english"=>"Option 4 English", "hindi"=>"Option 4 Hindi"}}], "answers"=>[["5c828b959579661ab17f86c3"]], "blanks"=>[]}, {"id"=>"5c828c509579661ab17f86ce", "question_text"=>{"english"=>"Mmcq Question in English", "hindi"=>"Mmcq Question in Hindi"}, "marks"=>1.0, "penalty"=>0.0, "partial_positive_marks"=>0.0, "partial_negative_marks"=>0.0, "question_type"=>"MmcqQuestion", "tags"=>[], "explaination"=>{"english"=>"Solution in english", "hindi"=>"Solution in hindi"}, "hint"=>{"english"=>"hint in english", "hindi"=>"hint in hindi"}, "actual_answer"=>{"english"=>"Answer in english", "hindi"=>"Answer in hindi"}, "options"=>[{"id"=>"5c828c509579661ab17f86ca", "fraction"=>true, "answer"=>{"english"=>"Option 1 English", "hindi"=>"Option 1 Hindi"}}, {"id"=>"5c828c509579661ab17f86cb", "fraction"=>true, "answer"=>{"english"=>"Option 2 English", "hindi"=>"Option 2 Hindi"}}, {"id"=>"5c828c509579661ab17f86cc", "fraction"=>false, "answer"=>{"english"=>"Option 3 English", "hindi"=>"Option 3 Hindi"}}, {"id"=>"5c828c509579661ab17f86cd", "fraction"=>false, "answer"=>{"english"=>"Option 4 English", "hindi"=>"Option 4 Hindi"}}], "answers"=>[["5c828c509579661ab17f86ca", "5c828c509579661ab17f86cb"]], "blanks"=>[]}, {"id"=>"5c828cd99579661ab17f86d5", "question_text"=>{"english"=>"Matrix Question in English", "hindi"=>"Matrix Question in Hindi"}, "marks"=>1.0, "penalty"=>0.0, "partial_positive_marks"=>0.0, "partial_negative_marks"=>0.0, "question_type"=>"McqMatrixQuestion", "tags"=>[], "explaination"=>{"english"=>"Solution in english", "hindi"=>"Solution in hindi"}, "hint"=>{"english"=>"hint in english", "hindi"=>"hint in hindi"}, "actual_answer"=>{"english"=>"Answer in english", "hindi"=>"Answer in hindi"}, "options"=>[{"id"=>"5c828cd99579661ab17f86d1", "fraction"=>true, "answer"=>{"english"=>"English: p->5;q->1,2;r->1;s->1,4;", "hindi"=>"Hindi: p->5;q->1,2;r->1;s->1,4;"}}, {"id"=>"5c828cd99579661ab17f86d2", "fraction"=>false, "answer"=>{"english"=>"English: p->1,5;q->1,2,3;r->1;s->1,3;", "hindi"=>"Hindi: p->1,5;q->1,2,3;r->1;s->1,3;"}}, {"id"=>"5c828cd99579661ab17f86d3", "fraction"=>false, "answer"=>{"english"=>"English: p->2,5;q->1,3;r->1;s->1,4;", "hindi"=>"Hindi: p->2,5;q->1,3;r->1;s->1,4;"}}, {"id"=>"5c828cd99579661ab17f86d4", "fraction"=>false, "answer"=>{"english"=>"English:p->2,4;q->1,2;r->1;s->1,4;", "hindi"=>"Hindi: p->2,4;q->1,2;r->1;s->1,4;"}}], "answers"=>[["5c828cd99579661ab17f86d1"]], "blanks"=>[]}]}, {"id"=>"5c828cd99579661ab17f86d5", "question_text"=>{"english"=>"Matrix Question in English", "hindi"=>"Matrix Question in Hindi"}, "marks"=>1.0, "penalty"=>0.0, "partial_positive_marks"=>0.0, "partial_negative_marks"=>0.0, "question_type"=>"McqMatrixQuestion", "tags"=>[], "explaination"=>{"english"=>"Solution in english", "hindi"=>"Solution in hindi"}, "hint"=>{"english"=>"hint in english", "hindi"=>"hint in hindi"}, "actual_answer"=>{"english"=>"Answer in english", "hindi"=>"Answer in hindi"}, "options"=>[{"id"=>"5c828cd99579661ab17f86d1", "fraction"=>true, "answer"=>{"english"=>"English: p->5;q->1,2;r->1;s->1,4;", "hindi"=>"Hindi: p->5;q->1,2;r->1;s->1,4;"}}, {"id"=>"5c828cd99579661ab17f86d2", "fraction"=>false, "answer"=>{"english"=>"English: p->1,5;q->1,2,3;r->1;s->1,3;", "hindi"=>"Hindi: p->1,5;q->1,2,3;r->1;s->1,3;"}}, {"id"=>"5c828cd99579661ab17f86d3", "fraction"=>false, "answer"=>{"english"=>"English: p->2,5;q->1,3;r->1;s->1,4;", "hindi"=>"Hindi: p->2,5;q->1,3;r->1;s->1,4;"}}, {"id"=>"5c828cd99579661ab17f86d4", "fraction"=>false, "answer"=>{"english"=>"English:p->2,4;q->1,2;r->1;s->1,4;", "hindi"=>"Hindi: p->2,4;q->1,2;r->1;s->1,4;"}}], "answers"=>[["5c828cd99579661ab17f86d1"]], "blanks"=>[]}, {"id"=>"5c828d1f9579661ab17f86dc", "question_text"=>{"english"=>"AssertionReasonQuestion in English", "hindi"=>"AssertionReasonQuestion in Hindi"}, "marks"=>1.0, "penalty"=>0.0, "partial_positive_marks"=>0.0, "partial_negative_marks"=>0.0, "question_type"=>"AssertionReasonQuestion", "tags"=>[], "explaination"=>{"english"=>"Solution in english", "hindi"=>"Solution in hindi"}, "hint"=>{"english"=>"hint in english", "hindi"=>"hint in hindi"}, "actual_answer"=>{"english"=>"Answer in english", "hindi"=>"Answer in hindi"}, "options"=>[{"id"=>"5c828d1f9579661ab17f86d8", "fraction"=>true, "answer"=>{"english"=>"English: Statement-1 is True, Statement-2 is True; Statement-2 is the correct explanation of Statement-1.", "hindi"=>"Hindi: Statement-1 is True, Statement-2 is True; Statement-2 is the correct explanation of\nStatement-1."}}, {"id"=>"5c828d1f9579661ab17f86d9", "fraction"=>false, "answer"=>{"english"=>"English: Statement-1 is True, Statement-2 is True; Statement-2 is not a correct explanation of Statement-1.", "hindi"=>"Hindi: Statement-1 is True, Statement-2 is True; Statement-2 is not a correct explanation of Statement-1."}}, {"id"=>"5c828d1f9579661ab17f86da", "fraction"=>false, "answer"=>{"english"=>"English: Statement-1 is True, Statement-2 is False", "hindi"=>"Hindi: Statement-1 is True, Statement-2 is False"}}, {"id"=>"5c828d1f9579661ab17f86db", "fraction"=>false, "answer"=>{"english"=>"English:Statement-1 is False, Statement-2 is True.", "hindi"=>"Hindi: Statement-1 is False, Statement-2 is True."}}], "answers"=>[["5c828d1f9579661ab17f86d8"]], "blanks"=>[]}], "quiz_sections"=>[{"name"=>{"english"=>"Quiz Section 1 name in english", "hindi"=>"Quiz section 1 name in hindi"}, "instructions"=>{"english"=>"quiz section 1 instructions in english", "hindi"=>"quiz section 1 instructions in hindi"}, "question_ids"=>["5c828b959579661ab17f86c7", "5c828c509579661ab17f86ce"], "quiz_sub_sections"=>[]}, {"name"=>{"english"=>"Quiz Section 2 name in english", "hindi"=>"Quiz section 2 name in hindi"}, "instructions"=>{"english"=>"quiz section 2 instructions in english", "hindi"=>"quiz section 2 instructions in hindi"}, "question_ids"=>["5c828de79579661b5c7f86c5", "5c828e969579661b9f7f86c5", "5c828d5a9579661ab17f86e1"], "quiz_sub_sections"=>[]}, {"name"=>{"english"=>"Quiz Section 3 name in english", "hindi"=>"Quiz section 3 name in hindi"}, "instructions"=>{"english"=>"quiz section 3 instructions in english", "hindi"=>"quiz section 3 instructions in hindi"}, "question_ids"=>["5c828f009579661b9f7f86c8", "5c828cd99579661ab17f86d5", "5c828d1f9579661ab17f86dc"], "quiz_sub_sections"=>[]}]}

quiz_section_1 = QuizSection.create(question_ids:question_ids_1, quiz_id: quiz.id.to_s,quiz_section_language_specific_datas_attributes: [{name:'Quiz Section 1 name in english',instructions:'quiz section 1 instructions in english', language: 'english'}, {name:'Quiz section 1 name in hindi',instructions:'quiz section 1 instructions in hindi', language: 'hindi'}])

quiz_section_2 = QuizSection.create(question_ids:question_ids_2,quiz_id: quiz.id.to_s, quiz_section_language_specific_datas_attributes: [{name:'Quiz Section 2 name in english',instructions:'quiz section 2 instructions in english', language: 'english'}, {name:'Quiz section 2 name in hindi',instructions:'quiz section 2 instructions in hindi', language: 'hindi'}])

quiz_section_3 = QuizSection.create(question_ids:question_ids_3,quiz_id: quiz.id.to_s, quiz_section_language_specific_datas_attributes: [{name:'Quiz Section 3 name in english',instructions:'quiz section 3 instructions in english', language: 'english'}, {name:'Quiz section 3 name in hindi',instructions:'quiz section 3 instructions in hindi', language: 'hindi'}])




quiz.quiz_section_ids = [quiz_section_1.id.to_s, quiz_section_2.id.to_s, quiz_section_3.id.to_s]
quiz.key = "/quiz_zips/#{quiz.guid}.zip"
quiz.file_path = Rails.root.to_s + "/public/quiz_zips/#{quiz.guid}.zip"
quiz.save! #"818cd91f-17b1-4d28-8fcc-e3c80d63dea8"

quiz_targeted_group_data = {password:'4123', time_open:(Time.now.to_i), time_close:(Time.now.to_i+1.year.to_i), show_score_after:1*60, show_answers_after:2*60, published_by:1, group_id:2, message_subject:'Quiz publish subject', message_body:'quiz publish body',quiz_id:quiz.id}
qtg = QuizTargetedGroup.create(quiz_targeted_group_data)
qtg = QuizTargetedGroup.find("5c84f28b957966328b7205d3")
{"id"=>"5c84f28b957966328b7205d3", "quiz_id"=>"5c84f12695796631967205de", "password"=>"4123", "shuffle_questions"=>false, "shuffle_options"=>false, "pause"=>false, "time_open"=>1552216714, "time_close"=>1583773666, "show_score_after"=>60, "show_answers_after"=>120, "message_subject"=>"Quiz publish subject", "message_body"=>"quiz publish body", "max_no_of_attempts"=>100, "evaluate_server_side"=>false,"key_update"=>false}

quiz.as_json(with_key:true,with_language_support:true)