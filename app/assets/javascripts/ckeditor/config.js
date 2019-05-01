/**
 * @license Copyright (c) 2003-2018, CKSource - Frederico Knabben. All rights reserved.
 * For licensing, see https://ckeditor.com/legal/ckeditor-oss-license
 */

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


//CKEDITOR.on('instanceReady', function(ev){
//    var dtd = CKEDITOR.dtd;
//
//    for ( var e in CKEDITOR.tools.extend( {},
//        dtd.$block,
//        dtd.$listItem,
//        dtd.$tableContent )
//        ) {
//        ev.editor.dataProcessor.writer.setRules(v,
//            {
//                indent: false,
//                breakBeforeOpen: false,
//                breakAfterOpen: false,
//                breakBeforeClose: false,
//                breakAfterClose: false
//            }
//        );
//    }
//});



