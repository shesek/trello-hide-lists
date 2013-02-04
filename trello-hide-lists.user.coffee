`
// ==UserScript==
// @match https://trello.com/board/*
// ==/UserScript==
`
# Execute everything in full webpage content
((fn) ->
  s = document.createElement 'script'
  s.textContent = '(' + fn + ')()'
  document.body.appendChild s
) body = -> # `body =` needed to resolve coffee parsing bug, https://github.com/jashkenas/coffee-script/issues/2692

  # Reverse parameter order, purely for sugar
  debounce = (fn, time) -> _.debounce time, fn
  
  # CSS
  ((style) -> $('<style>').attr(type:'text/css').text(style).appendTo('head')) """
    .toggler { cursor: pointer; }
    .toggler.active { background-color: gainsboro; }
    #board-header .org-name.toggler { overflow: visible; }
  """

  # Tell Trello to re-render its list, as some siez needs to change according
  # to the number of visible lists
  recalc_list_size = -> do Controller.boardCurrent.view.renderLists
  # Runs after the user has stopped showing/hiding lists for 2s
  recalc_list_size_debounced = debounce 2000, recalc_list_size
  

  # toggle the visibillity state of a list/button
  toggle = (list, button, from_cookie = false) ->
    button.toggleClass 'active'
    # removing the "list" class makes it "invisible" to Trello UI internals
    list.toggle().toggleClass 'list invisible-list'
    unless from_cookie
      do save_cookie
      do recalc_list_size_debounced
  
  # Wait for Trello to finish rendering its lists, by detecting new .list elements
  # and waiting for it to settle down for 200 ms
  $(document).on 'DOMNodeInserted', '.list', debounce 200, ->
    unless $('.toggler').length
      $('#board-header')
        # Create all buttons
        .append $('.list, .invisible-list').map (_, list) ->
          list = $ list
          button = $('<a>')
            .text(name = list.find('h2')[0].firstChild.textContent)
            .addClass('quiet org-name toggler active')
          button.click -> toggle list, button
          toggle list, button, true unless is_active name
          button.get(0) # http://bugs.jquery.com/ticket/8897
      do recalc_list_size if $('.invisible-list').length
  
  # Cookie handling
  cookie_name = 'inactive_lists_' + location.href.match(/\/board\/[^\/]+\/([^\/]+)/)?[1] or 'unknown'
  save_cookie = ->
    document.cookie = \
        cookie_name + '=|' \
      + $('.toggler:not(.active)').map(->@textContent).get().join('|') \
      + '|'
  is_active = (name) -> !(document.cookie.match ///#{cookie_name}=[^;]*\|#{name}\|///)
