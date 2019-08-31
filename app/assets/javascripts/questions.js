function add_accordion_to_searches(){
    $("#searchOptions ").css({
        //code below not working
        "border-color":"#60c8cd !important"
    })

    $("#searchOptions .searchFilterContainer,.searchIdBoxContainer").css({
        "padding":"1em 1.2em"
    })

    $("#tag_list_search_by_id").css({width:220, height:40})

    $("#searchOptions h3").css({
        "background-color":"#FFFFFF",
        height:25,
        "line-height":"25px",
        "padding-left":3
    })
    $("#searchOptions").accordion({
        icons:false,
        animated:"slide"
    });
    automatically_clear_search_by_id();
}

function stylizeButtons(){
    //input type submit becomes a button
    $('input[type=submit]:not(".search_iconview")').button();

    $( "#questionBankSearch" ).button();
    $( "#addQuestions" ).button();
    $( "#addQuestions_dup" ).button();
    $( "#addQuestionsSimpleTest").button();
    $( "#addQuestionsSimpleTest_dup").button();
    //$("#search_for_questions").button();
    $("#goToAssessmentPreview").button();
}

function automatically_clear_search_by_id(){
    $( "#searchOptions" ).on( "accordionchange", function( event, ui ) {
        // Resets the value of the question search by id field upon changing to search by filters mode
        if (ui.newHeader.text()=="Search by Filters")
        {   $("#tag_list_search_by_id").val("");
    }
} )
}
function stylizeButtons(){
    //input type submit becomes a button
    $( "#addQuestionsSimpleTest").button();
    $( "#addQuestionsSimpleTest_dup").button();
}

function empty_question_array() {
    question_array = []
    try{
        $( "#addQuestions" ).button( "disable" );
        $( "#addQuestions_dup" ).button( "disable" );
    }
    catch(err) {
        //nothing here
    }
    try{
        $( "#addQuestionsSimpleTest" ).button( "disable" );
        $( "#addQuestionsSimpleTest_dup" ).button( "disable" );
    }
    catch(err) {
        //nothing here
    }
}
