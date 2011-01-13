var timeout   = {};
var last      = {};
var overtime  = {
  feed: 4  * 60 * 60,
  meds: 12 * 60 * 60,
  poop: 7  * 60 * 60 * 24,
};
var button_map = {
  p: 'pee',
  o: 'poop',
  m: 'meds',
  f: 'feed',
  w: 'wakeup',
  z: 'sleep',
  s: 'spitup',
  d: 'solids',
};
var button_re;
var queue = [];
var submit_timeout = null;

function getTimers() {
  var str = $.cookie('baby_timers');
  if (str === null || str.length == 0) return []; 
  return str.split(',');
}

function setTimers(timers) {
  $.cookie('baby_timers', timers.join(','), { expires: 30 * 6 });
}

function inputPageInit() {
  $('#simple-spitup').click(function() {
    var quantity = prompt('How many grams?');
    if (quantity === null) return false;
    if (quantity >= 0) $('#quantity').val(quantity);
    return true;
  });

  $('#simple-solids').click(function () {
    var notes = prompt('Quantity and type?');
    if (notes === null) return false;
    if (notes.length > 0) $('#notes').val(notes);
    return true;
  });

  $(document).keypress(handleShortcutKeys);

  $('#time').focus();
  getTimers().forEach(function (id) {
    var timer = $('#' + id + '-timer');
    timer.addClass('running');
    openTimer(timer);
  });
  $('#timers .button').click(toggleTimer);

  var button_keys = [];
  for (var c in button_map)
    if (button_map.hasOwnProperty(c)) button_keys.push(c);

  $('#shortcuts').html('shortcuts: ' + button_keys.map(function (c) {
    var word = button_map[c];
    var i    = word.indexOf(c);
    if (i > -1)
      return word.substr(0, i) + '<b>' + c + '</b>' + word.substr(i+1);
    else
      return '(<b>' + c + '</b>) ' + word;
  }).join(', '));

  button_re = new RegExp('[' + button_keys.join('') + ']');

  setInterval(function () {
    $.get(last_update_url, null, function (new_lu) { 
      if (new_lu > last_update) window.location.reload();
    });
  }, 300000);
}

function toggleTimer() {
  var button = $(this);
  var name   = button.attr('id').replace(/-button$/, '');
  var div    = $('#' + name + '-timer');

  if (div.hasClass('running')) {
    clearTimeout(timeout[name]);
    div
      .removeClass('running')
      .find('.timer')
        .text('');
    button.text('+');
    setTimers(getTimers()
      .filter(function (t) { return t != name; }));
  }
  else {
    openTimer(div, true);
  }
}

function openTimer(div, update_session) {
  var name = div.attr('id').replace(/-timer$/, '');
  if (update_session) setTimers(getTimers().concat(name));
  div.addClass('running');
  updateTimer(name, div.find('.timer'), last[name]);
  div.find('.button').text('-');
}

function updateTimer(name, timer, last_update) {
  var wait  = 60000;
  var secs  = Math.round((Date.now() - last_update) / 1000);
  if (secs < 0) secs = 0;
  var ot    = overtime[name] && secs > overtime[name];
  var days  = Math.floor(secs / 86400); secs %= 86400;
  var hours = Math.floor(secs / 3600);  secs %= 3600;
  var mins  = Math.floor(secs / 60);
  var str = '';
  if (days) {
    str += days  + 'd';
    wait *= 60;
  }
  if (hours) str += hours + 'h';
  if (!days) str += mins  + 'm';
  timer.text(str + ' ago');
  if (ot) timer.addClass('overtime');
  else timer.removeClass('overtime');
  timeout[name] = 
    setTimeout(function () { updateTimer(name, timer, last_update); }, wait);
}

function openLightBox() {
  $('#queue').jqm(); 
}

function closeLightBox() {
}

function handleShortcutKeys(e) {
  if (e.ctrlKey) return true;

  var c = String.fromCharCode(e.which);
  if (button_re.test(c)) {
    // if (submit_timeout) clearTimeout(submit_timeout);
    $('#simple-' + button_map[c]).click();
  }
  else if (c == 't') {
    // openLightBox();
    // if (submit_timeout) clearTimeout(submit_timeout);
    // closeLightBox();
    $('#time').focus();
  }
  else if (c == 'n') {
    var notes = prompt('Notes', $('#notes').val());
    if (notes !== null)
      $('#notes').val(notes);
  }
  else {
    return true;
  }

  return false;
}
