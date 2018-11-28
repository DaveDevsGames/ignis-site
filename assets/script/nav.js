var nav_button = document.getElementById('nav-button');
var nav_box = document.getElementById('nav-box');
var nav_open = false;

// CSS controls the display of the button and initial transform of the nav
// on narrow media. The button simply modifies the transform.
nav_button.onclick = function(){
  if(nav_open) {
    nav_box.style.transform = 'translate(-100%, 3rem)';
    nav_button.innerHTML = '&#9776;';
    nav_open = false;
  }
  else {
    nav_box.style.transform = 'translate(0, 3rem)';
    nav_button.innerHTML = '&#9587;';
    nav_open = true;
  }
};

// Resests the css transform when the window resizes. This prevents js from
// overriding the default css for the nav after the nav button has been
// clicked.
document.body.onresize = function(){
  if(nav_box.style.transform != '') {
    nav_box.style.transform = '';
  }
};
