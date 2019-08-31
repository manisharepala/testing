
//resets passage question by removing all the questions ahssociated with the paragraphs
function reset_passage_question(link){
    var $passage_question = link.closest(".passage_question")
    $passage_question.find(".question_container").each(function(){
        $(this).find(".remove_questions")[0].click();
    })
    reset_question($passage_question);
    $("#questionAdder")[0].click();
    do_numbering($passage_question.find(".question_container"));
}

// resets the full question and triggers the change handler
function reset_question(question_object){
    question_object.find('input:text, input:password, input:file, select, textarea').val('');
    try{
        question_object.find(".full_text").each(function(){
            tinymce.get($(this).attr("id")).setContent('');
        })
    }
    catch(err){
        console.log("Tinymce apparently failed but works upon using try catch")
    }
    question_object.find('input:radio, input:checkbox').removeAttr('checked').removeAttr('selected');
    reset_option_values(question_object);
    show_selected_option_set("multichoice",question_object);
}

function attachLiveEventsForDynamicEntities(){
    // shows explanation field for the question upon clicking
    $(".show_explanation_field").on('click',function(){
        var $this = $(this);
        var $explanation_field = $this.closest(".question_container").find(".extra_explanation");
        $explanation_field.show();
        $this.hide();
    })
}


// assign reset handler for reset button in the question options
$("#reset_question").on('click',function(){
    var $question_object = $(this).closest(".question_container");
    reset_question($question_object);
});
