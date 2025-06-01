$(document).ready(function () {
// Login or create new user
//Make sure passwords match ref: https://gist.github.com/grayghostvisuals/6984561

jQuery.validator.addMethod( 'passwordMatch', function(value, element) {
    
    // The two password inputs
    var password = $("#password").val();
    var confirmPassword = $("#passwordConfirm").val();

    // Check for equality with the password inputs
    if (password != confirmPassword ) {
        return false;
    } else {
        return true;
    }

}, "Your Passwords Must Match");


$('#newUserForm').validate({
    // rules
    rules: {
        password: {
            required: true,
            minlength: 3
        },
        passwordConfirm: {
            required: true,
            minlength: 3,
            passwordMatch: true // set this on the field you're trying to match
        }
    },

    // messages
    messages: {
        password: {
            required: "What is your password?",
            minlength: "Your password must contain more than 3 characters"
        },
        passwordConfirm: {
            required: "You must confirm your password",
            minlength: "Your password must contain more than 3 characters",
            passwordMatch: "Your Passwords Must Match" // custom message for mismatched passwords
        }
    }
});//end validate

function ConvertFormToJSON(form){
    var array = jQuery(form).serializeArray();
    var json = {};
    
    jQuery.each(array, function() {
        json[this.name] = this.value || '';
    });
    
    return json;
}  
/* 
$('#loginForm').submit(function(event) {
      event.preventDefault(); // Prevent the default form submission
      var form = $(this);
      var login = $(this).attr('action');
      var check = $(this).data('url')
      var inputValue = $('#user').val();
      var dynamicCheck = checkDynamicData(inputValue, check);
      
      if (dynamicCheck) {
        //$(this).submit();
        console.log('success1');
      } else {
        console.log('fail1');
        //alert('Submission failed: Invalid input value.');
        // $('#myInput').val('');
      }
      //console.log(dynamicCheck);
    });

    // Simulate dynamic data check function
    function checkDynamicData(value,url) {
      $.get(url, { user: value}, function(data) {
            return true;
            console.log(data);
        }).fail( function(jqXHR, textStatus, errorThrown) {
            return false;
            console.log(data);
            //alert('User does not exist, please try again, or create an account');
            //console.log(textStatus);
        });
    }
*/

$("#newUserForm").submit(function( event ) {
  event.preventDefault();
  var form = $(this);
  var url = $(this).attr('action');
  var data = ConvertFormToJSON(form);
  $.ajaxSetup({
    contentType: "application/json; charset=utf-8"
  });
  $.post(url, JSON.stringify(data), function(data) {
   var message = $(data).attr('message')
   if(message == 'success') {
      alert('Success! Please log in');
      $('#newUserModal').modal('hide');
   } else {
      alert('This username already exists.');
      $(form)[0].reset();
    }
  }).fail( function(jqXHR, textStatus, errorThrown) {
    console.log(textStatus);
  });
  //end post
});

$("#resetForm").submit(function( event ) {
  event.preventDefault();
  var form = $(this);
  var url = $(this).attr('action');
  var data = ConvertFormToJSON(form);
  $.ajaxSetup({
    contentType: "application/json; charset=utf-8"
  });
  $.post(url, JSON.stringify(data), function(data) {
   var message = $(data).attr('message')
   if(message == 'success') {
      alert('Password has been reset. Please log in.');
      $('#resetModal').modal('hide');
   } else {
      alert('Error');
      $(form)[0].reset();
    }
  }).fail( function(jqXHR, textStatus, errorThrown) {
    console.log(textStatus);
  });
  //end post
});

//loginModal
 
$('#logout').click(function(event) {
  event.preventDefault();
  var url = $(this).attr('href');
  $.get(url, function(data) {
    window.location.reload()
 });
});

// Function to set font size and save to localStorage
function setFontSize(size) {
    $('body').css('font-size', size + 'px');
    localStorage.setItem('fontSize', size);
}

// Check if font size is stored in localStorage
if (localStorage.getItem('fontSize')) {
    var savedFontSize = localStorage.getItem('fontSize');
    setFontSize(savedFontSize);
}

//Set fontFamily  
function setFontFamily(family) {
    $('body').css('font-family', family);
    localStorage.setItem('fontFamily', family);
}

    // Check if font size is stored in localStorage
if (localStorage.getItem('fontFamily')) {
    var savedFontFamily = localStorage.getItem('fontFamily');
    setFontSize(savedFontFamily);
}

$('#fontPlus').click(function(event) {
  event.preventDefault();
  var currentSize = parseInt($('body').css('font-size'));
  setFontSize(currentSize + 2);
  //$("body *").css('font-size','+=2');
});

$('#fontMinus').click(function(event) {
  event.preventDefault();
  var currentSize = parseInt($('body').css('font-size'));
  setFontSize(currentSize - 2);
  //$("body *").css('font-size','-=2');
});

$('#fontNormal').click(function(event) {
  event.preventDefault();
  $("body").css('font-size','16px');
});

$('#sansSerif').click(function(event) {
  event.preventDefault();
  $("body *").css('font-family','sans-serif');
  $("#serif").css('font-family','serif');
  setFontFamily('sans-serif');
});

$('#serif').click(function(event) {
  event.preventDefault();
  $("body *").css('font-family','serif');
  $("#sansSerif").css('font-family','sans-serif');
  setFontFamily('serif');
});

$('#fontFamilyReset').click(function(event) {
  event.preventDefault();
  $("body *").css('font-family','serif');
  $("#sansSerif").css('font-family','sans-serif');
});

//test audio links
$(window).scroll(function(e){ 
    var distanceFromTop = $(this).scrollTop();
    if (distanceFromTop >= 400) {
        $('#audioFileDiv').addClass('fixed');
        //add conditional close btn
    } else {
        $('#audioFileDiv').removeClass('fixed');
    }
});
//audioLink
$('.audioLink').on('click', function() {
    $('#carouselAudio').carousel($('.audioLink').index(this));
});

$('.imageLink').on('click', function() {
    $('#pageImagesCarousel').carousel($('.imageLink').index(this));
    console.log('Image number:: ' + $('.imageLink').index(this));
});

$('#content').on('click', '.imageLink', function() {
    event.preventDefault();
    var myModal = new bootstrap.Modal(document.getElementById('teiPageImages'))
    myModal.show();
    $('#pageImagesCarousel').carousel($('.imageLink').index(this));
     
});
  
});

