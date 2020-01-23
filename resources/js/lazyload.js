/* Annotation functions.*/
$(document).ready(function () {

console.log('We are going to have some fun today!');

/* .lazyContent */
const config = {
  root: null, // avoiding 'root' or setting it to 'null' sets it to default value: viewport
  rootMargin: '0px',
  threshold: 0.5
};

//const contents = $('.lazyContent')
const divs = document.querySelectorAll('[data-src]');

let observer = new IntersectionObserver(function (entries, self) {
  entries.forEach(entry => {
      if (entry.isIntersecting) {
        //preloadImage(entry.target);
        //intersectionHandler(entry);
        var div = $(entry.target);
        var src = div.data("src")
        var page = div.data("page")
        var work = div.data("work")
        var url = src + '?getPage=' + page + '&workID=' + work
        //console.log('get src: ' + url)
        $.post(url, function(data) {  
               div.html(data);
               //console.log('loading: ' + data)
            }, "html"); 
            
        //li.html('test');
        //console.log('is interesecting.');
        // Observer has been passed as self to our callback
        self.unobserve(entry.target);
      }
  });
}, config);

divs.forEach(div => { observer.observe(div); });

/* 
 * $.get('../../modules/data.xql', function(data) {
            console.log('Good job: ' + data);  
               intersectionHandler(entry);
            }, "html"); 
 * 
 */
 /* 
function intersectionHandler(entry) {
    let li = $(entry.target);
    li.html(items[Math.floor(Math.random() * items.length)]);
   //$(entry).text('Test entry ');
   //entry.html('Test entry ');
}
*/
/* Tried this, just kept loading over and over
$('div').lazy({
  removeAttribute: false, // disbale attribute remove because you will need them every time
  
  lazyLoader: function(element, response) {
   var ajax = this.config('ajax').bind(this);
   ajax(element, response);

  	setInterval(function() {
    	ajax(element, () => {});
    }, 3000);
  },

  // ajax response for jsfiddle demo
  ajaxCreateData: function() {
  	return {html: "<strong>response " + Date.now() + "</strong>"};
  }
});
*/


});