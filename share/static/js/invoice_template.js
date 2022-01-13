//constructor
var svgCanvasEmbed = null;
var svgEditor = null;
function setNoSaveWarning(){
    svgCanvasEmbed.frame.contentWindow.svgCanvas.undoMgr.resetUndoStack();
}
function init_embed() {
    var svgEditFrameName = 'svgedit';
    var frame = document.getElementById(svgEditFrameName);
    svgCanvasEmbed = new EmbeddedSVGEdit(frame);
    // Hide main button, as we will be controlling new/load/save etc from the host document
    var doc = frame.contentDocument;
    if (!doc)
    {
        doc = frame.contentWindow.document;
    }
    var mainButton = doc.getElementById('main_button');
    mainButton.style.display = 'none';
    svgEditor = frame.contentWindow.svgEditor;
}
//private
function getSvgString(){
    return svgCanvasEmbed.frame.contentWindow.svgCanvas.getSvgString();
}
function setSvgStringToEditor( svgParsedString ){
    //alert('setSvgStringToEditor: '+svgParsedString);
    svgCanvasEmbed.setSvgString( svgParsedString )(
        function(data,error){
            if(error){
            }else{
                svgCanvasEmbed.zoomChanged('', 'canvas');
                setNoSaveWarning();
            }
        }
    );
}
function setSvgStringToPreview( svgParsedString, q, data ) {
    var previewIframe = document.getElementById('svgpreview');
    if(!previewIframe){
        return;
    }    
    //alert('setSvgStringToPreview: svgParsedString='+svgParsedString+';data='+data+';');
    if ($.browser.msie) {
        //we need to repeat query to server for msie if we don't want send template string via GET method
        if(!q){
            var dataPreview = data;
            dataPreview.tt_viewmode = 'parsed';
            dataPreview.tt_type = 'svg';
            dataPreview.tt_output_type = 'svg';
            dataPreview.tt_sourcestate = dataPreview.tt_sourcestate || 'saved';
            q = uriForAction( dataPreview, 'template' );
            //alert('setSvgStringToPreview: q='+q+';');
        }
        previewIframe.src = q;
    }else{
        previewIframe.src = "data:text/html," + encodeURIComponent(svgParsedString);
    }
}
function fetchSvgToEditor( data ) {
    var q = uriForAction( data, 'template' );
    //alert('fetchSvgToEditor: q='+q+';');
    $.ajax({
        url: q,
    }).done( function ( httpResponse ){ 
        setSvgStringToEditor( httpResponse );
    });
}

function fetchInvoiceTemplateData(data) {
    var q = uriForAction(data, 'template');
    var queryObj = {
        url: q,
        type: 'GET',
    };
    $.ajax(queryObj).done(function(templatedata) {
        setSvgStringToEditor(templatedata);
    });
}

function clearTemplateForm(data){
    $('#template_editor_form').css('visibility','hidden');
    //$('#load_previewed_control').css('display', 'none' );
    $('#load_saved_control').css('display', 'none' );
    if(!data){
        data = {};
    }
    data.tt_sourcestate = 'default';
    fetchInvoiceTemplateData(data, 1);//1 = no show form again, just clear it up to default state
}

function savePreviewed( data, callback ){
    var svgString = getSvgString();
    var q = uriForAction( data, 'template_previewed' ); 
    //alert('savePreviewedAndShowParsed: svgString='+svgString+'; q='+q+';');
    //alert('savePreviewedAndShowParsed: q='+q+';');
    //save 
    q=formToUri(q);
    $.post( q, { template: svgString } )
    .done( function( httpResponse ){
        // & show template
        //alert('savePreviewed: httpResponse='+httpResponse+';');
        //alert('savePreviewed: callback='+callback+'; typeof='+(typeof callback)+';');
        
        //setSvgStringToPreview( httpResponse, q, data )
        
        if(typeof callback == 'function'){
            //alert('savePreviewed.1: callback='+callback+'; typeof='+(typeof callback)+';');
            callback(httpResponse, q, data);
        }else{
            eval(callback);
        }
        
        //$('#load_previewed_control').css('display', 'inline' );
        //refresh list after saving - there is nothin that can be changed in templates list after preview refresh
        //refreshAjaxList( 'template', data );
    } );
}
function savePreviewedAndShowParsed( data ){
    savePreviewed(data, setSvgStringToPreview );
    //var svgString = getSvgString();
    //var q = uriForAction( data, 'template_previewed' ); 
    ////alert('savePreviewedAndShowParsed: svgString='+svgString+'; q='+q+';');
    ////alert('savePreviewedAndShowParsed: q='+q+';');
    ////save 
    //q=formToUri(q);
    //$.post( q, { template: svgString } )
    //.done( function( httpResponse ){
    //    // & show template
    //    //alert('savePreviewedAndShowParsed: httpResponse='+httpResponse+';');
    //    setSvgStringToPreview( httpResponse, q, data )
    //    //$('#load_previewed_control').css('display', 'inline' );
    //    //refresh list after saving - there is nothin that can be changed in templates list after preview refresh
    //    //refreshAjaxList( 'template', data );
    //} );
}

function saveTemplate( data, callback ) {	 
    var svgString = getSvgString();
    var q = uriForAction( data, 'template_saved' ); 
    q=formToUri(q);
    //alert('saveTemplate: q='+q+';');
    $.ajax( {
        url: q,
        type: "POST",
        //datatype: 'json',
        data: { template: svgString },
    } ).done( function( jsonResponse ) {
        if(jsonResponse.aaData && jsonResponse.aaData.form){
            $('form[name=template_editor]').loadJSON(jsonResponse.aaData.form);
        }
        $('#load_saved_control').css('display', 'inline' );
        if(typeof callback == 'function'){
            //alert('saveTemplate.1: callback='+callback+'; typeof='+(typeof callback)+';');
            callback(jsonResponse, q, data);
        }else{
            eval(callback);
        }
        setNoSaveWarning();
        //refreshAjaxList( 'template', data );
    });
}

