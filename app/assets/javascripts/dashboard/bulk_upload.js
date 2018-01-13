mainFunction = function() {
  var urlCount = 2
  $('#add-url-btn').click(function() {
    var input = "<input class='url-input' type='text' placeholder='paste url here' name='url_" + urlCount + "'/>"
    $('#bulk-upload-btn').before(input)
    urlCount++
  })
}

var controller = $('meta[name=psj]').attr('controller')
var action = $('meta[name=psj]').attr('action')

if (controller == 'dashboard' && action == 'bulk_upload') {
  mainFunction()
}





