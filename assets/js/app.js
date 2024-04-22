// import jQuery from "./jquery.min";
// window.$ = window.jQuery = jQuery;
// import { jstree } from './jstree.min';
// import { slick } from './slick';
// import { notify } from './bootstrap.notify';
// import { DataTable } from './datatables';
import { Bootstrap } from './bootstrap.bundle.min';
import { commerceApp_ } from './commerce_app.js';
import { phxApp_ } from './phx_app.js';
import { memberApp_ } from './member_app.js';
import { Socket } from "./phoenix.js"
import { phoenixModel } from './phoenixModel.js';
import { MENUS } from './menu.js';


$("html").attr("data-bs-theme", localStorage.getItem("data-bs-theme"))
window.showRP = false
window.toggleMcart = false
var useSw = false,
  isDev = window.location.hostname == "localhost";

if (isDev) {

  // phxApp_.post("admin_menus", { scope: "admin_menus", list: MENUS })
  useSw = false
}
if ('serviceWorker' in navigator && useSw) {
  navigator.serviceWorker.register('/sw.js')
    .then(registration => {
      console.log('Service Worker registered with scope:', registration.scope);
    })
    .catch(error => {
      console.error('Service Worker registration failed:', error);
    });
}
var langPrefix = "en";
window.translationRes = "";


function evalCountry(countryName) {
  var prefix = "en"

  if (countryName == "Thailand") {
    prefix = "th"
  }
  if (countryName == "Vietnam") {
    prefix = "vn"
  }
  if (countryName == "China") {
    prefix = "cn"
  }

  return prefix;
}


try {
  if (localStorage.region != null) {
    langPrefix = evalCountry(localStorage.region)
  }
  // translationRes = phxApp_.api("translation", { lang: langPrefix });
  translationRes = {}
} catch (error) {
  console.error("Error fetching translation:", error);
}
$.fn.extend({
  customHtml: async function(newHtml) {

    var translation_map = Object.keys(translationRes);
    var v2 = translation_map.reduce((acc, key) => {

      var regex = new RegExp(key, "g");

      return acc.replace(regex, translationRes[key]);
    }, newHtml);


    return this.html(v2);
  },
  customAppend: async function(newHtml) {

    var translation_map = Object.keys(translationRes);
    var v2 = translation_map.reduce((acc, key) => {

      var regex = new RegExp(key, "g");
      return acc.replace(regex, translationRes[key]);
    }, newHtml);


    return this.append(v2);
  }
});

window.phoenixModel = phoenixModel;
window.phoenixModels = []
window.phxApp = phxApp_
phxApp_.api("countries", {}, null, (e) => {
  window.countries = e
  phxApp_.countries_ = e
})
if (isDev) {

  window.commerceApp = commerceApp_
  window.memberApp = memberApp_

}

window.addEventListener(
  "popstate",
  function(event) {
    try {

      // supposing rerun the navigate?
      if (history.valueOf().state != null) {
        // var adder = new Function(history.valueOf().state.fn);

        // console.log(history.valueOf().state.fn)
        window.back = true;
        window.parsePage = true;

        phxApp.navigateTo(history.valueOf().state.route)

        // adder();
      } else {
        phxApp.notify("cant back")
        phxApp.navigateTo("/home")
      }
    } catch (e) {
      // alert("!")

      console.log("!")
      // window.init();
    }
  },
  true
);

const route_list = [
  { html: "devices.html", title: "Devices", route: "/devices", public: true },
  { html: "thank_you.html", title: "Login", route: "/thank_you", public: true },

]
route_list.forEach((v, i) => {
  phxApp_.route_names.push(v)
})


phxApp_.navigateTo();

const socket = new Socket("/socket", { params: { token: window.userToken } });

window.socket = socket;
socket.connect();

var buildFreshUrl = function(link) {
  var date = Math.round(Date.now() / 1000).toString();
  var url = link.href.replace(/(\&|\\?)vsn=\d*/, '');
  var newLink = document.createElement('link');
  var onComplete = function() {
    if (link.parentNode !== null) {
      link.parentNode.removeChild(link);
    }
  };

  newLink.onerror = onComplete;
  newLink.onload = onComplete;
  link.setAttribute('data-pending-removal', '');
  newLink.setAttribute('rel', 'stylesheet');
  newLink.setAttribute('type', 'text/css');
  newLink.setAttribute('href', url + (url.indexOf('?') >= 0 ? '&' : '?') + 'vsn=' + date);
  link.parentNode.insertBefore(newLink, link.nextSibling);

  return newLink;
};

var repaint = function() {
  var browser = navigator.userAgent.toLowerCase();
  if (browser.indexOf('chrome') > -1) {
    setTimeout(function() { document.body.offsetHeight; }, 25);
  }
};

var cssStrategy = function() {
  var reloadableLinkElements = window.parent.document.querySelectorAll(
    'link[rel=stylesheet]:not([data-no-reload]):not([data-pending-removal])'
  );

  [].slice
    .call(reloadableLinkElements)
    .filter(function(link) { return link.href })
    .forEach(function(link) { buildFreshUrl(link) });

  repaint();
};

var pageStrategy = function(chan) {
  chan.off('assets_change');
  window.top.location.reload();
};


var reloadStrategies = {
  css: cssStrategy,
  page: pageStrategy
};
if (isDev) {

  const rsocket = new Socket("/phoenix/live_reload/socket", { params: { token: window.userToken } });
  rsocket.connect();
  var chan = rsocket.channel('phoenix:live_reload', {})
  chan.on('assets_change', function(msg) {
    var reloadStrategy = reloadStrategies[msg.asset_type] || reloadStrategies.page;
    setTimeout(function() { reloadStrategy(chan); }, 1000);
  });
  chan.join();
}



$(document).on("click", "a.navi", function(event) {
  phxApp.show()
  event.preventDefault();
  setTimeout(() => {
    if ($(this).attr("href").includes("#")) {

    } else {

      phxApp_.navigateTo($(this).attr("href"))
    }
  }, 200)

});