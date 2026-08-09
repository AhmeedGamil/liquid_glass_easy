// The only JavaScript on the site: copy buttons.
//
// Everything else — navigation, layout, the collapsing menu — is HTML and
// CSS, so the pages work with JS off and are readable before it runs.
document.addEventListener('click', function (e) {
  var btn = e.target.closest('.copy, .copy-inline');
  if (!btn) return;

  // A block button sits beside its <pre>; an inline one wraps its own code.
  var inline = btn.classList.contains('copy-inline');
  var code = inline ? btn.querySelector('code')
                    : btn.parentElement.querySelector('code');
  if (!code) return;

  navigator.clipboard.writeText(code.innerText).then(function () {
    var target = inline ? code : btn;
    var was = target.textContent;
    target.textContent = 'Copied';
    btn.classList.add('done');
    setTimeout(function () {
      target.textContent = was;
      btn.classList.remove('done');
    }, 1500);
  });
});
