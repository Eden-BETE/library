/* ================================================================
   CHATBOT — custom.js
   ================================================================ */

// ---- Auto-scroll vers le bas ----
const chatObserver = new MutationObserver(() => {
  const el = document.getElementById('chatbot_ui');
  if (el) el.scrollTop = el.scrollHeight;
});

document.addEventListener('DOMContentLoaded', () => {
  const el = document.getElementById('chatbot_ui');
  if (el) chatObserver.observe(el, { childList: true, subtree: true });
});

// ---- Toggle collapse ----
$(document).on('click', '#chatbot_toggle', function () {
  const body = document.getElementById('chatbot_body');
  if (!body) return;
  const isHidden = body.style.display === 'none';
  body.style.display = isHidden ? 'flex' : 'none';
  body.style.flexDirection = 'column';
  $(this).text(isHidden ? '−' : '+');
});

// ---- Envoyer avec Entrée ----
$(document).on('keypress', '#chatbot_input', function (e) {
  if (e.which === 13 && !e.shiftKey) {
    e.preventDefault();
    $('#chatbot_send').click();
  }
});

// ---- Indicateur de chargement ("...") ----
$(document).on('click', '#chatbot_send', function () {
  const input = document.getElementById('chatbot_input');
  if (!input) return;
  const val = input.value.trim();
  if (!val) return;

  // Envoie la vraie valeur à Shiny via l'input caché
  Shiny.setInputValue('chatbot_input_val', val, {priority: 'event'});

  // Vide le champ visuellement
  input.value = '';

  // Bulle optimiste
  const ui = document.getElementById('chatbot_ui');
  if (!ui) return;

  const userBubble = document.createElement('div');
  userBubble.className = 'chat-bubble user';
  userBubble.id = 'chat-optimistic-user';
  userBubble.textContent = val;
  ui.appendChild(userBubble);

  const typing = document.createElement('div');
  typing.className = 'chat-typing';
  typing.id = 'chat-typing-indicator';
  typing.innerHTML = '<span></span><span></span><span></span>';
  ui.appendChild(typing);

  ui.scrollTop = ui.scrollHeight;
});
// ---- Retire l
