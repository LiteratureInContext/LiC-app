            $(document).ready(function () {
                //Add Coursepack on check
                var coursepack = []
                var coursepackworks = []
                
                //Add selected works to coursepackworks
                $('.createCoursepack').on('click', function(e){ // on change of state
                    e.preventDefault(e);
                    $('#response').modal('show');
                    $('#saveCoursepackModal').show();
                    $('#addToCoursepackModal').hide();
                    $('.results :checked').each(function() { 
                        coursepackworks.push({id: $(this).val() , title: $(this).data('title') });
                    });
                 });
                 
                //Create new coursepack
                $('.addCoursepackTitle').on('click', function(e){ // on change of state
                    e.preventDefault(e);
                    coursepack.push({coursepackID: 'coursepack' , coursepackTitle: $('#coursepackTitle').val(), coursepackDesc: $('#coursepackDesc').val(), works: coursepackworks });
                    $.ajaxSetup({
                        contentType: "application/json; charset=utf-8"
                    });
                    $.post('modules/lib/coursepack.xql',JSON.stringify({ 'coursepack': coursepack }), function(data) {
                        $('#saveCoursepackModal').hide();
                        $('#responseBody').html(data);
                        //alert(data);
                    }).fail( function(jqXHR, textStatus, errorThrown) {
                           console.log(textStatus);
                   });
                 });
                 
                 //Add selected works to coursepackworks
                $('.addToCoursepack').on('click', function(e){ // on change of state
                    e.preventDefault(e);
                    $('#response').modal('show'); 
                    $('#saveCoursepackModal').hide();
                    $('#addToCoursepackModal').show();
                    $('.results :checked').each(function() { 
                        coursepackworks.push({id: $(this).val() , title: $(this).data('title') });
                    });
                 });
                 
                  //Create new coursepack
                $('.saveToCoursepack').on('click', function(e){ // on change of state
                    e.preventDefault(e);
                    coursepack.push({coursepackID: $('#addToCoursepackID').val(), works: coursepackworks });
                    $.ajaxSetup({
                        contentType: "application/json; charset=utf-8"
                    });
                    $.post('modules/lib/coursepack.xql?action=update',JSON.stringify({ 'coursepack': coursepack }), function(data) {
                        $('#addToCoursepackModal').hide();
                        $('#responseBody').html(data);
                        //alert(data);
                    }).fail( function(jqXHR, textStatus, errorThrown) {
                           console.log(textStatus);
                   });
                 });
                
                //Delete work from coursepack
                $('.removeWork').on('click', function(e){ // on change of state
                    e.preventDefault(e);
                    var url = $(this).data('url')
                    $.get(url, function(data) {
                        location.reload();
                        console.log('removed');
                    }).fail( function(jqXHR, textStatus, errorThrown) {
                    console.log(textStatus);
                    });
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
                 $('.footnoteRef a').click(function(e) {
                    e.stopPropagation();
                    e.preventDefault();
                    var link = $(this);
                    var href = $(this).attr('href');
                    var content = $(href).html()
                    $('#footnoteDisplay').css('display','block');
                    $('#footnoteDisplay').css({'top':e.pageY-95,'left':e.pageX+25, 'position':'absolute'});
                    $('#footnoteDisplay div.content').html( content );    
                });
            });