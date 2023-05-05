$(function() {

  const alertPlaceholder = document.getElementById('alert-placeholder')
  const alert = (message, type) => {
    const wrapper = document.createElement('div')
  wrapper.innerHTML = [
    `<div class="alert alert-${type} alert-dismissible" role="alert">`,
    `   <div>${message}</div>`,
    '   <button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button>',
    '</div>'
  ].join('')

    alertPlaceholder.append(wrapper)
  }
  
  $('#tryit-btn').attr('disabled', true);
  
  $('#submit-btn').on("click", function(e) {
    e.preventDefault();
    
    var username = encodeURI($('#username').val());
    
    if ( username != "" ) {
      $('#submit-btn').attr('disabled', true);
      $('#submit-btn-container').hide();
      
      url = '/cgi-bin/qrcode.cgi?username=' + username;
      
      $.ajax({
        url : url,
        success: function(data) {
          console.log(data);
          
          $('#qrcode').html(data.qrcode);
          $('#qrcode-container').show();
          
          $('#secret').val(data.secret);
          $('#secret-container').show();

          $('#instructions-container').show();
          $('#tryit-btn').attr('disabled', false);
          $('#tryit-btn-container').show();
        },
        error: function() {
        }
      });
    }
    
    return false;
  });

  $('#tryit-btn').on("click", function(e) {
    e.preventDefault();

    $('#secret-container').hide();
    $('#qrcode-container').hide();
    $('#access-code-container').show();
    $('#instructions-container').hide();
    
    $('#login-btn-container').show()
    $('#login-btn').attr('disabled', false);
    
    $('#tryit-btn-container').hide();
    $('#tryit-btn').attr('disabled', true);
    
    return false;
  });
  
  $('#login-btn').on("click", function(e) {

    e.preventDefault();

    if ( access_code != "" && username != "" ) {
      $('#login-btn').attr('disabled', true);
      
      data = {
        "username" : $('#username').val(),
        "access_code" : $('#access_code').val()
      };
      
      $.ajax({
        url : '/cgi-bin/qrcode.cgi',
        method: 'POST',
        data: data,
        success: function(data) {
          console.log(data);

          if ( data.matched ) {
            alert('Success!', 'success');
            $('#login-btn').attr('disabled', false);
          }
          else {
            alert('Try again?', 'danger');
            $('#login-btn').attr('disabled', false);
          }
        },
        error: function() {
        }
      });
    }
    
    return false;
  });
  
});
