var articles = document.getElementsByTagName('ARTICLE');
var images = Array();
var modal = document.getElementById('modal');
var modal_image = modal.getElementsByTagName('IMG')[0];
var modal_caption = modal.getElementsByTagName('FIGCAPTION')[0];
var close = modal.getElementsByTagName('BUTTON')[0];

// There may be multiple article tags on a page. The images from each are
// pushed to an array.
for(var i = 0; i < articles.length; i++) {
  var article = articles.item(i);
  var article_images = article.getElementsByTagName('IMG');
  for(var j = 0; j < article_images.length; j++){
    images.push(article_images.item(j));
  }
}

// Replace the modal dialog's image and display the dialog on image click.
// Alt image text is used for a caption.
for(var i = 0; i < images.length; i++) {
  var image = images[i];
  image.onclick = function(){
    modal.style.display = 'block';
    modal_image.src = this.src;
    modal_caption.innerHTML = this.alt;
  };
}

// Remove the modal dialog's image + caption and hide the dialog on close.
close.onclick = function(){
  var modal = document.getElementById('modal');
  modal.style.display = 'none';
  modal_image.src =  "";
  modal_caption.innerHTML = '';
};
