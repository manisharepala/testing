CKEDITOR.editorConfig = function( config )
{
    // Define changes to default configuration here. For example:
    // config.language = 'fr';
    // config.uiColor = '#AADC6E';

    config.mathJaxLib = '//cdnjs.cloudflare.com/ajax/libs/mathjax/2.7.4/MathJax.js?config=TeX-AMS_HTML';
    config.extraPlugins = 'mathjax';

    /* Filebrowser routes */
    // The location of an external file browser, that should be launched when "Browse Server" button is pressed.
    //config.filebrowserBrowseUrl = "/assessment/ckeditor/attachment_files";
    //
    //// The location of an external file browser, that should be launched when "Browse Server" button is pressed in the Flash dialog.
    //config.filebrowserFlashBrowseUrl = "/assessment/ckeditor/attachment_files";
    //
    //// The location of a script that handles file uploads in the Flash dialog.
    //config.filebrowserFlashUploadUrl = "/assessment/ckeditor/attachment_files";
    //
    //// The location of an external file browser, that should be launched when "Browse Server" button is pressed in the Link tab of Image dialog.
    //config.filebrowserImageBrowseLinkUrl = "/assessment/ckeditor/pictures";

    // The location of an external file browser, that should be launched when "Browse Server" button is pressed in the Image dialog.
    config.filebrowserImageBrowseUrl = "/assessment/ckeditor/pictures";

    //// The location of a script that handles file uploads in the Image dialog.
    config.filebrowserImageUploadUrl = "/assessment/ckeditor/pictures?";
    //
    //// The location of a script that handles file uploads.
    //config.filebrowserUploadUrl = "/assessment/ckeditor/attachment_files";

    config.allowedContent = true;

    // Toolbar groups configuration.
    //config.toolbar = [
    //    { name: 'document', groups: [ 'mode', 'document', 'doctools' ], items: [ 'Source'] },
    //    { name: 'clipboard', groups: [ 'clipboard', 'undo' ], items: [ 'Cut', 'Copy', 'Paste', 'PasteText', 'PasteFromWord', '-', 'Undo', 'Redo' ] },
    //    // { name: 'editing', groups: [ 'find', 'selection', 'spellchecker' ], items: [ 'Find', 'Replace', '-', 'SelectAll', '-', 'Scayt' ] },
    //    // { name: 'forms', items: [ 'Form', 'Checkbox', 'Radio', 'TextField', 'Textarea', 'Select', 'Button', 'ImageButton', 'HiddenField' ] },
    //    { name: 'links', items: [ 'Link', 'Unlink', 'Anchor' ] },
    //    { name: 'insert', items: [ 'Image', 'Flash', 'Table', 'HorizontalRule', 'SpecialChar' ] },
    //    { name: 'paragraph', groups: [ 'list', 'indent', 'blocks', 'align', 'bidi' ], items: [ 'NumberedList', 'BulletedList', '-', 'Outdent', 'Indent', '-', 'Blockquote', 'CreateDiv', '-', 'JustifyLeft', 'JustifyCenter', 'JustifyRight', 'JustifyBlock' ] },
    //    '/',
    //    { name: 'styles', items: [ 'Styles', 'Format', 'Font', 'FontSize' ] },
    //    { name: 'colors', items: [ 'TextColor', 'BGColor' ] },
    //    { name: 'basicstyles', groups: [ 'basicstyles', 'cleanup' ], items: [ 'Bold', 'Italic', 'Underline', 'Strike', 'Subscript', 'Superscript', '-', 'RemoveFormat' ] }
    //];
    //
    //config.toolbar_mini = [
    //    { name: 'paragraph', groups: [ 'list', 'indent', 'blocks', 'align', 'bidi' ], items: [ 'NumberedList', 'BulletedList', '-', 'Outdent', 'Indent', '-', 'Blockquote', 'CreateDiv', '-', 'JustifyLeft', 'JustifyCenter', 'JustifyRight', 'JustifyBlock' ] },
    //    { name: 'styles', items: [ 'Font', 'FontSize' ] },
    //    { name: 'colors', items: [ 'TextColor', 'BGColor' ] },
    //    { name: 'basicstyles', groups: [ 'basicstyles', 'cleanup' ], items: [ 'Bold', 'Italic', 'Underline', 'Strike', 'Subscript', 'Superscript', '-', 'RemoveFormat' ] },
    //    { name: 'insert', items: [ 'Image', 'Table', 'HorizontalRule', 'SpecialChar' ] }
    //];



    CKEDITOR.on('instanceReady', function(ev){
        var el = [ "p", "div", "table", "tbody", "tr", "td", "h1", "h2", "h3", "h4", "h5", "h6", "ul", "ol", "pre", "address", "blockquote", "dl", "fieldset", "form", "hr", "noscript", "center"];
        el.forEach(function(v) {
            ev.editor.dataProcessor.writer.setRules(v,
                {
                    indent: false,
                    breakBeforeOpen: false,
                    breakAfterOpen: false,
                    breakBeforeClose: false,
                    breakAfterClose: false
                }
            );
        });
    });
};
