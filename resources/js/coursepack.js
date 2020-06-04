            $(document).ready(function () {
                //Add Coursepack on check
                var coursepack = []
                var coursepackworks = []
                
                $.ajaxSetup({
                    contentType: "application/json; charset=utf-8",
                    statusCode: {
                        401: function(){
                            //console.log('Restricted. Please login.');
                            //alert('This function is restricted. Please register or login.');
                            $('#loginModal').modal('show');
                        }
                    }
                });
                
                //Create new coursepack
                $('.createCoursepack').on('click', function(e){ // on change of state
                    e.preventDefault(e);
                    $.get('userInfo', function(data) {
                        $('#response').modal('show');
                        $('#saveCoursepackModal').show();
                        $('#addToCoursepackModal').hide();
                        $('.results :checked').each(function() { 
                            coursepackworks.push({id: $(this).val() , title: $(this).data('title') });
                        });
                    }).fail( function(jqXHR, textStatus, errorThrown) {
                           console.log(errorThrown);
                    });
                 });
                 
                //Add selected works to coursepack
                $('.addCoursepackTitle').on('click', function(e){ // on change of state
                    e.preventDefault(e);
                    var url = $(this).data('url')
                    $.get('userInfo', function(data) {
                        coursepack.push({coursepackID: 'coursepack' , coursepackTitle: $('#coursepackTitle').val(), coursepackDesc: $('#coursepackDesc').val(), works: coursepackworks });
                        $.post(url,JSON.stringify({ 'coursepack': coursepack }), function(data) {
                            $('#saveCoursepackModal').hide();
                            $('#responseBody').html(data);
                        }).fail( function(jqXHR, textStatus, errorThrown) {
                               console.log(textStatus);
                       });
                    }).fail( function(jqXHR, textStatus, errorThrown) {
                           console.log(errorThrown);
                    });   
                 });
                 
                //Add selected works to coursepackworks
                $('.addToCoursepack').on('click', function(e){ // on change of state
                    e.preventDefault(e);
                    $.get('userInfo', function(data) {
                        $('#response').modal('show'); 
                        $('#saveCoursepackModal').hide();
                        $('#addToCoursepackModal').show();
                        $('.results :checked').each(function() { 
                            coursepackworks.push({id: $(this).val() , title: $(this).data('title') });
                        });
                    }).fail( function(jqXHR, textStatus, errorThrown) {
                           console.log(errorThrown);
                    });                        
                 });
                 
                //Create new coursepack
                $('.saveToCoursepack').on('click', function(e){ // on change of state
                    e.preventDefault(e);
                    var url = $(this).data('url')
                    coursepack.push({coursepackID: $('#addToCoursepackID').val(), works: coursepackworks });
                    console.log(coursepack)
                    //$.get('userInfo', function(data) {
                        $.post(url + '?action=update',JSON.stringify({ 'coursepack': coursepack }), function(data) {
                            $('#addToCoursepackModal').hide();
                            $('#responseBody').html(data);
                            //alert(data);
                        }).fail( function(jqXHR, textStatus, errorThrown) {
                               console.log(textStatus);
                       });
                   // }).fail( function(jqXHR, textStatus, errorThrown) {
                   //        console.log(errorThrown);
                   // });                       
                 });
                
                //Delete coursepack
                $('.deleteCoursepack').click(function(event) {
                  event.preventDefault();
                  var url = $(this).attr('href');
                  $.get('userInfo', function(data) {
                    $.get(url, function(data) {
                        var redirect = $(data).find('#url').text()
                        window.location = redirect;
                        //console.log(data);
                    });
                  }).fail( function(jqXHR, textStatus, errorThrown) {
                     console.log(textStatus);
                  });  
                }); 

                //Delete work from coursepack
                $('.removeWork').on('click', function(e){ // on change of state
                    e.preventDefault(e);
                    var url = $(this).data('url')
                    $.get('userInfo', function(data) {
                        $.get(url, function(data) {
                           location.reload();
                            //console.log(data);
                        }).fail( function(jqXHR, textStatus, errorThrown) {
                            console.log(textStatus);
                        });
                     }).fail( function(jqXHR, textStatus, errorThrown) {
                            console.log(textStatus);
                   });   
                });
                
                //expand a single work
                $('.expand').on('click', function(e){ // on change of state
                    e.preventDefault(e);
                    var url = $(this).data('url')
                    var current = $(this) 
                    var $expandedText = $(current).closest('.row').find('.expandedText');
                    //If annotation results are empty load via ajax, otherwise toggle to show or hide div
                    if($expandedText.is(':empty')){
                         $.get(url, function(data) {
                               $(current).closest('.row').find('.expandedText').html(data);
                           }, "html"); 
                           $(this).find('.glyphicon').toggleClass('glyphicon-plus-sign').toggleClass('glyphicon-minus-sign');
                       } else {
                         $expandedText.toggle();
                         $(this).find('.glyphicon').toggleClass('glyphicon-plus-sign').toggleClass('glyphicon-minus-sign');
                       } 
                     
                });
                
                //Use Rangy to save selected HTML to coursepack
                $('.rangy').on('click', function(e){ // on change of state
                    e.preventDefault(e);
                    var selection = rangy.getSelection().toHtml(),
                        url = $(this).data('url'),
                        workID = $(this).data('workid'),
                        workTitle = $(this).data('worktitle'); 
                    coursepackworks.push({id: workID , title: workTitle, text: selection});
                    $('#coursepackTools').toggle( "slide" );
                    $('#response').modal('show');
                    $('#saveCoursepackModal').hide();
                    $('#addToCoursepackModal').show();
                    
                    //console.log(selection.attr('id'));
                });
                
                //test to trigger rangy popup
                /* 
                $('body').on( 'mouseup', function(){
                   $('#rangy').show();
                    console.log('something has been selected! Yay!');
                    var sel = rangy.getSelection();
                    if( sel.length > 0 ){
                      console.log('something has been selected! Yay!');
                    }
                  });
                   */ 
                  
                 $('#coursepackTools .close').on('click', function(e){ // on change of state
                    e.preventDefault(e);
                    $('#coursepackTools').toggle( "slide" ); 
                 }); 
                 
                 //Clear modal response body
                 $('.modalClose').on('click', function(e){ // on change of state
                    e.preventDefault(e);
                    $('#responseBody').empty(); 
                    $('#coursepackTitleGroup').show();
                 }); 
                 
                 //Hide footnotes. 
                 $('html').click(function() {
                    $('#footnoteDisplay').hide();
                    $('#footnoteDisplay div.content').empty();
                 })
                 
                 //Stop footnoteDisplay from closing on click, only hide when clicked outside of div
                 $("#footnoteDisplay").click(function(e){
                      e.stopPropagation();
                  });
                 
                 //Footnotes 
                 $( '#content' ).on( 'click', '.footnoteRef a', function (e) {
                    e.stopPropagation();
                    e.preventDefault();
                    var link = $(this);
                    var href = $(this).attr('href');
                    var content = $(href).closest('.footnote').html()
                    $('#footnoteDisplay').css('display','block');
                    $('#footnoteDisplay').css({'top':e.pageY-95,'left':e.pageX+25, 'position':'absolute'});
                    $('#footnoteDisplay div.content').html( content ); 
                    console.log(href)
                });
                
                //clear form when close modal
                $('.modal').on('hidden.bs.modal', function(){
                    $(this).find('form').trigger('reset');
                });
                
            }); 
          