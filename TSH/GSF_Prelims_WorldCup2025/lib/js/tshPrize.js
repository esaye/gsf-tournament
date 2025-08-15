"use strict";
var prizes = [ ];
var prizeNo;

window.addEventListener('click', function(e) {
  if (e.clientX << 1 > window.innerWidth) nextWinner();
  else previousWinner();
  });

window.addEventListener('keydown', function (e) {
/*  console.log(e.key); */
  switch(e.key) {
    case 'Shift': case 'Control': case 'Alt':
      break;
    case 'ArrowLeft': case 'ArrowUp': case 'Backspace':
    case 'b': case 'B': case 'p': case 'P': 
      previousWinner();
      break;
    default: 
      nextWinner();
    }
  });

function loadWinner(winNo) {
  prizeNo = winNo;
  var pp = prizes[prizeNo];
  var ref = document.getElementById('tshPrzNumber');
  if (ref) ref.innerHTML = (winNo+1) + '/' + (prizes.length);
  ref = document.getElementById('tshPrzPhoto');
  if (ref) {
    if (pp[0].length) { ref.src = pp[0]; ref.style.visibility = 'visible'; }
    else { ref.style.visibility = 'hidden'; }
    }
  ref = document.getElementById('tshPrzCategory');
  if (ref) ref.innerHTML = pp[1];
  ref = document.getElementById('tshPrzName');
  if (ref) ref.innerHTML = pp[2];
  ref = document.getElementById('tshPrzValue');
  if (ref) ref.innerHTML = pp[3];
  }

function nextWinner() {
  if (prizeNo < prizes.length-1) loadWinner(++prizeNo);
  }

function previousWinner() {
  if (prizeNo > 0) loadWinner(--prizeNo);
  }

document.addEventListener('DOMContentLoaded', function () {
  loadWinner(0);
  });
1;
