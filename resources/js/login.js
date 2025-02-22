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

/* 
$('.authenticate').click(function(event) {
  event.preventDefault();
  var url = $(this).attr('href');
  $.get('userInfo', function(data) {
    $.get(url, function(data) {
        window.location = url;
    });
  }).fail( function(jqXHR, textStatus, errorThrown) {
     console.log(textStatus);
  });  
}); 

*/
/* 
 * function adjustFontSize(amount) {
    const textElement = document.getElementById("text");
    const currentSize = parseFloat(window.getComputedStyle(textElement).fontSize);
    textElement.style.fontSize = (currentSize + amount) + "px";
  }
 * 
 */
$('#fontPlus').click(function(event) {
  event.preventDefault();
  $("body *").css('font-size','+=1');
});
$('#fontMinus').click(function(event) {
  event.preventDefault();
  $("body *").css('font-size','-=2');
});
$('#fontNormal').click(function(event) {
  event.preventDefault();
  window.location.reload()
});
$('#sansSerif').click(function(event) {
  event.preventDefault();
  $("body *").css('font-family','sans-serif');
  $("#serif").css('font-family','serif');
});
$('#serif').click(function(event) {
  event.preventDefault();
  $("body *").css('font-family','serif');
  $("#sansSerif").css('font-family','sans-serif');
});
$('#fontFamilyReset').click(function(event) {
  event.preventDefault();
  window.location.reload()
});

});

