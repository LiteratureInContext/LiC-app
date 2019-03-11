/* Annotation functions.*/
$(document).ready(function () {
           
    // Get annotated elements 
    $('.getAnnotated').on('click', function(e){ // on change of state
        e.preventDefault(e);
        var workID = $(this).data('work-id');
        var contributorID = $(this).data('contributor-id');
        var current = $(this) 
        var $annotationsResults = $(current).closest('.annotations').find('.annotationsResults');
        //If annotation results are empty load via ajax, otherwise toggle to show or hide div
         if($annotationsResults.is(':empty')){
              $.get('modules/lib/annotations.xql', { doc: workID, contributorID: contributorID}, function(data) {
                    $(current).closest('.annotations').find('.annotationsResults').html(data);                 
                }, "html"); 
                $(this).find('.glyphicon').toggleClass('glyphicon-plus-sign').toggleClass('glyphicon-minus-sign');
            } else {
              $annotationsResults.toggle();
              $(this).find('.glyphicon').toggleClass('glyphicon-plus-sign').toggleClass('glyphicon-minus-sign');
            }
    });  
    
    // Get text annotations 
    $('.getTextAnnotated').on('click', function(e){ // on change of state
        e.preventDefault(e);
        var workID = $(this).data('work-id');
        var contributorID = $(this).data('contributor-id');
        var current = $(this) 
        var $annotationsResults = $(current).closest('.annotations').find('.textAnnotationsResults');
        //If annotation results are empty load via ajax, otherwise toggle to show or hide div
         if($annotationsResults.is(':empty')){
              $.get('modules/lib/annotations.xql', {type: 'text', doc: workID, contributorID: contributorID}, function(data) {
                    $(current).closest('.annotations').find('.textAnnotationsResults').html(data);                 
                }, "html"); 
                $(this).find('.glyphicon').toggleClass('glyphicon-plus-sign').toggleClass('glyphicon-minus-sign');
            } else {
              $annotationsResults.toggle();
              $(this).find('.glyphicon').toggleClass('glyphicon-plus-sign').toggleClass('glyphicon-minus-sign');
            }
    }); 
});