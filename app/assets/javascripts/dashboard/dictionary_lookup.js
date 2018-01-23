var entries = {}

var dictionaryLookup = function() {
  $('#prefix-input').keyup(function(e) {
    let prefix = e.target.value
    sendLookupRequest(prefix)
  })

  $('#edit-modal-cancel').click(function() {
    $('#edit-modal-wrapper').addClass('hidden')
  })

  $('#edit-modal-confirm').click(function() {
    sendEditRequest()
  })

  $('#success-confirm-btn').click(function() {
    $('#success-modal').addClass('hidden')
  })

  $('#error-confirm-btn').click(function() {
    $('#error-modal').addClass('hidden')
  })
}

var sendEditRequest = function() {
  let formData = $('#edit-form').serialize()
  $.post({
    url: '/edit_dictionary_entry',
    data: formData,
    success: function(entry) {
      hideEditModal()
      showSuccess('Successfully edited dictionary entry')
      updateEntry(entry)
    },
    error: function(err) {
      hideEditModal()
      showError('Something went wrong. Tell Max about it')
    }
  })
}

var updateEntry = function(entry) {
  var original = entry.original
  entries[original] = entry.translation
  $('#' + original).find('.dictionary-entry__translation').html(entry.translation)
}

var sendLookupRequest = function(prefix) {
  $.get({
    url: '/dictionary_complete/?prefix=' + prefix,
    success: function(res) {
      entries = res['results']
      displayResults(entries)
    },
    error: function(err) {console.log(err)}
  })
}

displayResults = function(entries) {
  $('#lookup-results').html('')
  Object.keys(entries).forEach(function(original) {
    let html = `<tr class='dictionary-entry' id='${original}'>
                  <td class='dictionary-entry__original'>${original}</td> -
                  <td class='dictionary-entry__translation'>${entries[original]}</td>
                  <td><button class='entry-edit-btn' data-original='${original}'>Edit</button</td>
               </tr>`
    $('#lookup-results').append(html)
  })
  putListenersOnEntries()
}

var putListenersOnEntries = function() {
  $('.entry-edit-btn').click(function(e) {
    var original = e.currentTarget.dataset.original
    openEditModal(original)
  })
}

var openEditModal = function(original) {
  $('#edit-modal-wrapper').removeClass('hidden')
  $('#edit-modal__original-dummy').html(original)
  $('#edit-modal__original').prop('value', original)
  $('#edit-modal__translation').prop('value', entries[original])
}

var hideEditModal = function() {
  $('#edit-modal-wrapper').addClass('hidden')
}

var showSuccess = function(message) {
  $('#success-modal').removeClass('hidden')
  $('#success-message').html(message)
}

var showError = function(message) {
  $('#error-modal').removeClass('hidden')
  $('#error-message').html(message)
}

// *********************************************************************

var controller = $('meta[name=psj]').attr('controller')
var action = $('meta[name=psj]').attr('action')

if (controller == 'dashboard' && action == 'dictionary_lookup') {
  dictionaryLookup()
}







