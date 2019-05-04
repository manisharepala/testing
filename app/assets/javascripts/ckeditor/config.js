
CKEDITOR.editorConfig = function( config ) {
    config.mathJaxLib = '//cdnjs.cloudflare.com/ajax/libs/mathjax/2.7.4/MathJax.js?config=TeX-AMS_HTML';
};


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
