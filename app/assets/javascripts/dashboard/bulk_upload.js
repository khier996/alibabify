mainFunction = function() {
  var urlCount = 1
  $('#add-url-btn').click(function() {
    urlCount++
    var input = `<div class='url-wrapper'>
                  <input class='url-input' type='text' placeholder='paste url here' name='url_${urlCount}' />
                </div>`
    $('#bulk-upload-btn').before(input)

    var clone = $('#collection-mold').clone()
    $('.url-wrapper').last().append(clone)
    $('.url-wrapper').last().find('select').removeClass('hidden').addClass('collections-dropdown').chosen()
    $('.url-wrapper').last().find('select').prop('name', `collections_${urlCount}[]`)
  })

  $('.collections-dropdown').removeClass('hidden').chosen()
}

var controller = $('meta[name=psj]').attr('controller')
var action = $('meta[name=psj]').attr('action')

if (controller == 'dashboard' && action == 'bulk_upload') {
  mainFunction()
}





