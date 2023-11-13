/* Annotation functions.*/
$(document).ready(function () {
    
    /* 
    $('.glyphicon').click(function () {
        $(this).toggleClass("glyphicon-plus-sign").toggleClass("glyphicon-minus-sign");
    });
    */
    
    //Get contributor contribution, 1st 5         getContributorAnnotations
    $('.getContributorAnnotations').on('click', function(e){ // on change of state
        e.preventDefault(e);
        var contributorID = $(this).data('contributor-id');
        var current = $(this) 
        var $annotationsResults = $(current).closest('.contributor').find('.contributorAnnotationsResults');
        //If annotation results are empty load via ajax, otherwise toggle to show or hide div
         if($annotationsResults.is(':empty')){
              $.get('modules/lib/annotations.xql', { contributorID: contributorID}, function(data) {
                    $(current).closest('.contributor').find('.contributorAnnotationsResults').html(data);
                }, "html"); 
                $(this).find('.glyphicon').toggleClass('glyphicon-plus-sign').toggleClass('glyphicon-minus-sign');
            } else {
              $annotationsResults.toggle();
              $(this).find('.glyphicon').toggleClass('glyphicon-plus-sign').toggleClass('glyphicon-minus-sign');
            }   
    });
    
    // Get annotated elements 
    $('#content').on('click', '.getAnnotated', function(e){ // on change of state
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
    
    // Get search/browse results, load dynamically 
    
    $('.getNestedResults').on('click', function(e){ // on change of state
        e.preventDefault(e);
        var workID = $(this).data('work-id');
        var contributorID = $(this).data('contributor-id');
        var authorID = $(this).data('author-id');
        var current = $(this) 
        var $annotationsResults = $(current).closest('.result').find('.nestedResults');
        //If annotation results are empty load via ajax, otherwise toggle to show or hide div
         if($annotationsResults.is(':empty')){
              $.get('modules/lib/browse.xql', {type: 'search', doc: workID, contributorID: contributorID, authorID: authorID}, function(data) {
                    $(current).closest('.result').find('.nestedResults').html(data);                 
                }, "html"); 
                $(this).find('.glyphicon').toggleClass('glyphicon-plus-sign').toggleClass('glyphicon-minus-sign');
            } else {
              $annotationsResults.toggle();
              $(this).find('.glyphicon').toggleClass('glyphicon-plus-sign').toggleClass('glyphicon-minus-sign');
            }
    });    

    $('.dynamicContent').on('click', function(e){ // on change of state
        e.preventDefault(e);
        var url = $(this).data('url');
        var current = $(this) 
        var $annotationsResults = $(current).closest('.result').find('.nestedResults');
        if($annotationsResults.is(':empty')){
              $.get(url, function(data) {
                    $(current).closest('.result').find('.nestedResults').html(data);                 
                }, "html"); 
                $(this).find('.glyphicon').toggleClass('glyphicon-plus-sign').toggleClass('glyphicon-minus-sign');
            } else {
              $annotationsResults.toggle();
              $(this).find('.glyphicon').toggleClass('glyphicon-plus-sign').toggleClass('glyphicon-minus-sign');
            }
        console.log('test dynamic content loading. TEST URL: ' + url);
        
    });
    
    $('.viewMore').on('click', function () {
        var text = $(this).text();
        if(text === "View All"){
          $(this).html('View Less');
        } else{
          $(this).text('View All');
       }
      });
      
  
     $('.showHide').on('click', function () {
        if($(this).find('.glyphicon').hasClass('glyphicon glyphicon-plus-sign'))
            {
               $(this).find('.glyphicon').toggleClass('glyphicon-plus-sign').toggleClass('glyphicon-minus-sign'); 
            }
            else
            {      
                $(this).find('.glyphicon').toggleClass('glyphicon-plus-sign').toggleClass('glyphicon-minus-sign'); 
            }
        }); 
});