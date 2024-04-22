import {
  ColumnFormater
} from './column_formatter.js';
import {
  commerceApp_
} from './commerce_app.js';
import {
  memberApp_
} from './member_app.js';


export let phxApp_ = {
  Page: {
    createTable(id, dom) {
      var html = `
            <div class="table-responsive">
                <table class="table"  style="width: 100%;" id="` + id + `">
                    <thead></thead>
                    <tbody></tbody>
                </table>
            </div>
    `
      $(dom).append(html)
    },
  },
  chosen_country_id_: null,
  countries_: [],
  route_names: [{
      html: "landing.html",
      title: "Home",
      route: "/home",
      public: true
    },


  ],
  render(componentName) {
    commerceApp_.components[componentName]()
  },
  rowData(params) {


    var dt = params.dataSource;
    window.currentSelector = dt.tableSelector
    var table = dt.table;
    var r = table.row(params.row);
    var rowData = table.data()[params.index]
    return rowData
  },
  override(j) {
    memberApp_.override(j)
  },
  updateUser(j) {
    memberApp_.updateUser(j)
  },
  login(dom) {
    memberApp_.login(dom)
  },
  logout() {
    memberApp_.logout()
  },
  user: null,
  hasCartItems() {
    console.log("checking...")
    console.log(commerceApp_.hasCartItems())
    return commerceApp_.hasCartItems() > 0
  },
  merchantCheckout(dom) {
    memberApp_.merchantCheckout(dom)
  },
  redeem(dom) {
    memberApp_.redeem(dom)
  },
  upgrade(dom) {
    memberApp_.upgrade(dom)
  },
  linkRegister(dom) {
    memberApp_.linkRegister(dom)
  },
  register(dom) {
    memberApp_.register(dom)
  },
  formatDate() {
    ColumnFormater.formatDate()
  },
  ping() {

    console.log("tell ping o")
  },
  reinit() {
    // var t = $(".dataTable").DataTable()
    // t.ajax.reload();

    $(".dataTable").each((i, v) => {
      if (v.offsetParent != null) {
        var phxModel = window.phoenixModels.filter((dv, di) => {
          return dv.tableSelector == "#" + v.id

        })[0]

        phxModel.reload();
      }
    })


  },
  evalTitle(label) {

    if (localStorage.getItem("default-lang") == "cn") {

      switch (label.replace(" ", "")) {
        case "Home":
          label = "首页"
          break;
        case "Profile":
          label = "个人"
          break;
        case "Upgrade":
          label = "升级"
          break;
        case "Restocks":
          label = "朴货"
          break;
        case "Registrations":
          label = "审核"
          break;
        case "Sales":
          label = "业绩"
          break;
        case "Commissions":
          label = "佣金"
          break;
        default:
          label = label

      }
    }


    return label
  },
  async navigateTo(route, additionalParamString) {
    if (route == null) {
      route = window.location.pathname
    }
    var current_pattern = route.split("/").filter((v, i) => {
      return v != "";
    })

    var match_1 = this.route_names.filter((rroute, i) => {
      var z = rroute.route.split("/").filter((v, i) => {
        return v != "";
      })


      if (z[z.length - 1].includes(":")) {
        return z.length == current_pattern.length
      } else {

        return z.length == current_pattern.length && z[z.length - 1] == current_pattern[z.length - 1];
      }
    })

    var match_2 =
      match_1.filter((rroute, i) => {
        var z = rroute.route.split("/").filter((v, i) => {
          return v != "";
        })
        return z[0] == current_pattern[0]
      })
    this.hide()
    // memberApp_.restoreUser();
    if (match_2.length > 0) {
      var params = {}
      match_2.forEach((rroute, i) => {
        var z = rroute.route.split("/").forEach((v, ii) => {
          if (v.includes(":")) {
            params[v.replace(":", "")] = current_pattern[ii - 1]
          }
        })
      })
      console.info(match_2)

      if (match_2[0].public) {

      } else {
        // await memberApp_.restoreUser()
        // console.log("resting?")

        // if (memberApp_.user != null) {

        // } else {
        //   // location = "/logout"
        //   phxApp_.navigateTo("/logout")
        // }
      }

      window.pageParams = params
      var xParamString = ""
      if (additionalParamString == null) {
        xParamString = ""
      } else {
        xParamString = additionalParamString
      }

      if (window.back) {
        window.back = false
      } else {
        var stateObj = {
          route: route,
          fn: `phxApp.navigateTo('` + route + `', '` + xParamString + `')`,
          params: params
        };
        window.stateObj = stateObj
        window.matchTitle = match_2[0].title
        window.matchRoute = route
        if (Object.keys(params).includes("title")) {
          history.pushState(stateObj, evalTitle(params.title), route);
          $("title").html(this.evalTitle(params.title))
        } else {
          history.pushState(stateObj, this.evalTitle(match_2[0].title), route);
          $("title").html(this.evalTitle(match_2[0].title))
        }
      }
      var nav = this.html("blog_nav.html")
      var footer_modals = this.html("footer_modals.html")
      var html = this.html(match_2[0].html)
      var initPage = `
      <div class="page-content pb-0">
        ` + html + `
      </div>
        ` + footer_modals + `
          `
      var keys = Object.keys(match_2[0])
      if (keys.includes("skipNav")) {
        $("#content").html(initPage)
        this.navigateCallback()
      } else {
        if (keys.includes("customNav")) {
          var nav = this.html(match_2[0].customNav)
        }
        $("#content").html(nav)
        $("#content").append(initPage)
        this.navigateCallback()
      }
      return match_2[0]
    } else {


      console.info(match_1)

      var nav = this.html("blog_nav.html")
      var footer_modals = this.html("footer_modals.html")
      var html = this.html("landing.html")
      var initPage = `
      <div class="page-content pb-0">
        ` + html + `
      </div>        ` + footer_modals + ``
      $("#content").html(nav)
      $("#content").append(initPage)
      this.navigateCallback()

    }
  },
  modal(options) {

    var default_options = {
      selector: "#myModal",
      body: ".modal-body",
      title: ".modal-title",
      foot: ".modal-footer",
      header: "Modal Header",
      content: "Here is content for modal body",
      footer: "",
      drawFn: () => {},
      autoClose: true

    }

    var keys =
      Object.keys(default_options)
    keys.forEach((v, i) => {
      this[v] = default_options[v]
    })
    keys.forEach((v, i) => {
      if (options[v] != null) {
        this[v] = options[v]
      }
    })
    $(this.selector).find(this.title).customHtml(this.header)
    $(this.selector).find(this.body).customHtml(this.content)
    $(this.selector).find(this.foot).customHtml(this.footer)
    $(this.selector).modal("show")

    this.drawFn();
    if (this.autoClose) {
      setTimeout(() => {
        $(this.selector).modal("hide")
      }, 5000);
    }
  },
  toast(options) {
    var default_options = {
      selector: "#notification-1",
      body: ".toast-body",
      title: ".tbody",
      foot: ".modal-footer",
      header: "Modal Header",
      content: "Here is content for modal body",
      footer: "",
      drawFn: () => {},
      autoClose: true
    }

    var keys =
      Object.keys(default_options)
    keys.forEach((v, i) => {
      this[v] = default_options[v]
    })
    keys.forEach((v, i) => {
      if (options[v] != null) {
        this[v] = options[v]
      }
    })



    $(this.selector).find(this.title).customHtml(this.header)
    $(this.selector).find(this.body).customHtml(this.content)

    $(this.selector).toast('show')
    this.drawFn();
    if (this.autoClose) {
      // setTimeout(() => {
      //   $(this.selector).toast('hide')
      // }, 15000);
    }



    // if (typeof stValidate === "function") {


    // }
  },
  notify(message, options) {
    if (options == null) {
      options = {}
    }

    var default_options = {
      delay: 2000,
      type: "info"
    }
    var keys = Object.keys(default_options)
    keys.forEach((v, i) => {
      this[v] = default_options[v]
    })
    keys.forEach((v, i) => {
      if (options[v] != null) {
        this[v] = options[v]
      }
    })


    var obj = {}
    var message_obj = {}

    if (typeof message == 'object') {
      message_obj = message
    } else {
      message_obj = {
        message: message
      }
    }

    var default_obj = {
      message: "Your text here",
      title: "System Message:",
      icon: "fa fa-exclamation-circle"
    }

    var keys = Object.keys(default_obj)
    keys.forEach((v, i) => {
      obj[v] = default_obj[v]
    })
    keys.forEach((v, i) => {
      if (message_obj[v] != null) {
        obj[v] = message_obj[v]
      }
    })
    try {
      if (typeof $.notify === "function") {
        console.log(options)
        $.notify(obj, options)

      } else {

        this.toast({
          content: obj.message,
          header: obj.title
        })
      }

    } catch (e) {
      this.toast({
        content: obj.message,
        header: obj.title
      })
    }


  },
  reflect(formData) {
    var object = {};
    formData.forEach((value, key) => {

      console.log(key)
      var childMap = {}

      if (key.includes("\[")) {
        console.log("has child")
        var parent = key.split("\[")[0]
        var child = key.split("\[")[1].split("\]")[0]
        childMap[child] = value;
        object[parent] = { ...object[parent],
          ...childMap
        };

      } else {
        // Reflect.has in favor of: object.hasOwnProperty(key)
        if (!Reflect.has(object, key)) {
          object[key] = value;
          return;
        }
        if (!Array.isArray(object[key])) {
          object[key] = [object[key]];
        }
        object[key].push(value);
      }

    });
    return object;
  },
  validateForm(selector, successCallback) {
    var failed_inputs =
      $(selector).find("[name]").filter((i, v) => {
        $(v).removeClass("is-invalid")
        return v.checkValidity() == false
      })

    if (failed_inputs.length > 0) {
      var labels = []
      failed_inputs.map((v, i) => {
        $(i).addClass("is-invalid")
        var label = $(i).closest('.input-style').find("label div").html()
        if (label == null) {
          label = $(i).attr("name")
        }
        labels.push(label)
      })
      phxApp_.notify("This input: " + labels.join(", ") + " is not valid!", {
        type: "danger"
      });
    } else {
      successCallback()

    }
  },
  form(dom, scope, successCallback, failedCallback, appendMap) {
    phxApp_.show()
    var prefix = "",
      formData = new FormData($(dom)[0])
    formData.append("scope", scope)

    if (appendMap != null) {

      var keys = Object.keys(appendMap)

      keys.forEach((k, i) => {
        formData.append(k, appendMap[k])
      })
    }
    if (scope == "login") {
      prefix = "/login"
    }
    var csrfToken = this.csrf_()
    $.ajax({
        url: "/api/webhook" + prefix,
        dataType: "json",
        headers: {
          "Authorization": "Basic " + (phxApp_.user != null ? phxApp_.user.token : null),
          'x-csrf-token': csrfToken
        },
        method: "POST",
        enctype: "multipart/form-data",
        processData: false, // tell jQuery not to process the data
        contentType: false,
        data: formData
      })
      .done(function(j) {
        phxApp_.hide()
        if (j.status == "ok") {
          phxApp_.notify("Added!", {
            type: "success"
          });
          try {
            if (j.res != null) {

              successCallback(j.res)
            }

          } catch (e) {

          }
        } else {

          if (j.reason != null) {
            phxApp_.notify("Not added! " + j.reason, {
              type: "danger"
            });
          } else {

            phxApp_.notify("Not added!", {
              type: "danger"
            });
          }

        }

      }).fail(function(e) {
alert("!!!")
        if (e.status == 403) {
          memberApp_.logout()
        }

        phxApp_.notify("Not added!", {
          type: "danger"
        });

      })

  },
  html(page) {
    $(".modal-body").each((i, v) => {
      $(v).html('')
    })


    var langPrefix = "v2";

    function evalCountry(countryName) {
      var prefix = "v2"

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

    if (localStorage.region != null) {
      langPrefix = evalCountry(localStorage.region)
    }

    var res = "";
    $.ajax({
      async: false,
      method: "get",
      url: "/html/" + langPrefix + "/" + page
    }).done((j) => {
      res = j
    })
    return res;
  },
  token: null,
  async csrf_(renew) {

    if (this.token == null) {
      // var token = await fetch('/api/get_csrf_token').then(response => response.json())
      this.token = $("input[name='_csrf_token_ori']").val()
    } else if (renew) {
      // var token = await fetch('/api/get_csrf_token').then(response => response.json())
      this.token = $("input[name='_csrf_token_ori']").val()
    } else {
      return this.token
    }


  },
  api(scope, params, failed_callback, successCallback) {
    var res = ""
    var csrfToken = this.csrf_()
    $.ajax({
      async: false,
      method: "get",
      headers: {
        "Authorization": "Basic " + (phxApp_.user != null ? phxApp_.user.token : null),
        'X-CSRF-Token': csrfToken
      },
      url: "/api/webhook?scope=" + scope,
      data: params
    }).done((j) => {
      console.log(j)
      if (successCallback != null) {

        successCallback(j)
      }
      res = j
    }).fail(function(e) {
      if (e.status == 403) {
        memberApp_.logout()
      }


      try {
        phxApp_.notify("Not Added! reason: " + e.responseJSON.reason, {
          type: "danger"
        });
      } catch (e2) {

        phxApp_.notify("Ops, somethings' not right!", {
          type: "danger"
        });
      }
      phxApp_.show()
      setTimeout(() => {

        if (failed_callback != null) {
          failed_callback()
        }
        phxApp_.hide()
      }, 500)

    });
    return res;
  },

  post(scope, params, failed_callback, successCallback) {
    var res = ""
    var csrfToken = this.csrf_(true)
    $.ajax({
      async: false,
      method: "post",
      headers: {
        '_blog_engine_key': memberApp_.user.token,
        "Authorization": "Basic " + (phxApp_.user != null ? phxApp_.user.token : null),
        'X-CSRF-Token': csrfToken
      },
      url: "/api/webhook?scope=" + scope,
      data: params
    }).done((j) => {
      if (successCallback != null) {

        successCallback(j)
      }
      res = j
    }).fail(function(e) {
      alert("!!")
      if (e.status == 403) {
        memberApp_.logout()
      }

      phxApp_.notify("Ops, somethings' not right!", {
        type: "danger"
      });

      setTimeout(() => {

        if (failed_callback != null) {
          failed_callback()
        }
        this.hide()
      }, 500)

    });
    return res;
  },
  evaluateLang() {

  },
  toTop() {
    $("body")[0].scrollIntoView();
  },
  async putToken() {
    var csrfToken = await this.csrf_(true)
    if ($("input#need-token")) {
      $("input[name='_csrf_token']").val($("input[name='_csrf_token_ori']").val())
    }
  },
  evalCart() {
    if (window.location.pathname.includes("merchant")) {
      
    $(".showMcart").toggleClass("d-none")
    $(".showCart").toggleClass("d-none")
    }
  },
  async navigateCallback() {


    memberApp_.restoreUser();
    commerceApp_.restoreCart();

    commerceApp_.restoreCart(true);
    this.user = memberApp_.user
    if (this.user != null) {

      this.user.wallets = null
    }
    try {

      commerceApp_.render();
    } catch (e) {

    }
    this.evaluateLang();
    this.toTop();
    this.hide();
    this.putToken();
    this.evalCart();



  },
  show() {
    console.log("drop shadow..")
    $(".wrapper-ring").show()
    setTimeout(() => {
      $(".wrapper-ring").hide()
    }, 1000)
  },
  hide() {
    console.log("hide shadow..")
    try {
      $(".wrapper-ring").hide()
    } catch (e) {}
  },
  repopulateFormInput(data, formSelector) {
    console.log(data)
    var inputs = $(formSelector).find("[name]");
    $(inputs).each(function(i, v) {
      var name = $(v).attr("aria-label");
      if (name == null) {
        name = $(v).attr("name")
      }
      var hidden_value = $(v).attr("aria-value");

      var parent = name.split("[")[0]
      var child = name.replace("[", "").replace("]", "").replace(parent, "")


      if ($(v).prop("localName") == "select") {

        console.log("is select")

        if (name.includes("[")) {
          $(v).val(data[parent][child]);
        } else {

          $(v).val(data[name]);
        }
      } else if (hidden_value != null) {
        $(v).val(hidden_value);
      } else if ($(v).hasClass("code")) {
        try {


          $(v).val(data[name]);
          var hid_inpt = document.createElement("input");
          hid_inpt.setAttribute("type", "hidden");
          hid_inpt.setAttribute("name", $(v).attr("name"));
          $(v).after(hid_inpt);
          var editor = ace.edit($("textarea")[0], {
            mode: "ace/mode/html",
            selectionStyle: "text"
          });
          editor.resize();
          window.editor = editor;
          editor.session.setUseWrapMode(true);
          editor.session.on("change", function(delta) {

            $(hid_inpt).val(window.editor.getValue());
            console.log("ace here")
          });
        } catch (e) {
          console.log(e)
          $(v).val(data[name]);
        }
      } else {
        if ($(v).attr("type") == "checkbox") {
          console.log("got data?")
          console.log(data[name])
          if ($(v).hasClass("many_2_many")) {
            var id = parseInt(v.name.split("][")[1].split("]")[0])

            try {
              var res = data[name].filter((v, i) => {
                return v.id == id
              })
              if (res.length > 0) {

                $(v).prop("checked", data[name]);
              }

            } catch (e) {

              console.log(e)
              $(v).prop("checked", false);

            }

          } else {

            $(v).prop("checked", data[name]);
          }
        } else {
          if (data != null) {
            console.log(name);
            console.log("name: " + name + ", data: " + data[name]);

            if (name.includes(".")) {

              try {

                var module_name = $(v).closest("form").attr("id")
                var assoc_val = name.split(".")
                if (assoc_val.length == 2) {

                  $(v).val(data[assoc_val[0]][assoc_val[1]]);
                  $(v).parent().append(`<input type='hidden' value="` + data[assoc_val[0]]['id'] + `" name="` + module_name + `[` + assoc_val[0] + `][id]"></input>`)

                }
                if (assoc_val.length == 3) {

                  $(v).val(data[assoc_val[0]][assoc_val[1]][assoc_val[2]]);
                  $(v).parent().append(`<input type='hidden' value="` + data[assoc_val[0]]['id'] + `" name="` + module_name + `[` + assoc_val[0] + `][id]"></input>`)

                }
                if (assoc_val.length == 1) {

                  $(v).val(data[assoc_val[0]]);
                  $(v).parent().append(`<input type='hidden' value="` + data[assoc_val[0]]['id'] + `" name="` + module_name + `[` + assoc_val[0] + `][id]"></input>`)

                }
              } catch (e) {

                console.log(e)
                $(v).val(data[name]);
              }

            } else if (name.includes("[")) {



              try {

                $(v).val(data[parent][child]);
              } catch (e) {
                console.log(e)
                $(v).val(data[name]);
              }


            } else if (name == "_csrf_token") {
              var toke = $("input[name='_csrf_token_ori']").val()

              $(v).val(toke);

            } else {
              try {
                $(v).val(data[name]);
              } catch (e) {

                console.log(e)
                console.log("missing dom?")

              }
            }

          } else {
            console.log("name: " + name + ", data: ?");
          }
        }
      }


    });


  },
  generateInputs(j, v, object, qv) {
    var input2 = "",
      alt_class = "col-12 col-lg-6",
      label_title = v.charAt(0).toUpperCase() + v.slice(1)

    if (typeof qv == "object") {
      if (qv.alt_name != null) {
        label_title = qv.alt_name
      }
      if (qv.alt_class != null) {
        alt_class = qv.alt_class
      }

    }
    var translation_map = Object.keys(translationRes);



    var label_title = translation_map.reduce((acc, key) => {

      var regex = new RegExp(key, "g");
      return acc.replace(regex, translationRes[key]);
    }, label_title);




    switch (j[v]) {
      case "string":
        // code block

        input2 = `<div class="` + alt_class + `">
                      <div class="ps-1 py-2">` + label_title + `</div>
                      <div class="col-sm-12">
                        <div class="form-group bmd-form-group">
                          <input type="text" aria-label="` + v + `" name="` + object + `[` + v + `]" class="form-control">
                        </div>
                      </div>
                    </div>`
        break;
      case "boolean":
        // code block

        input2 = `<div class="row d-flex align-items-center ">
                      <label class="offset-lg-1 col-sm-3 col-form-label text-start label-checkbox">` + label_title + `</label>
                      <div class="col-sm-6 checkbox-radios">
                        <div class="form-check">
                          <label class="form-check-label">
                            <input class="form-check-input" type="checkbox" aria-label="` + v + `" name="` + object + `[` + v + `]" value=""> This ` + v + `
                            <span class="form-check-sign">
                              <span class="check"></span>
                            </span>
                          </label>
                        </div>
                        
                      </div>
                    </div>`
        break;
      case "integer":
        // code block
        if (v.includes("id")) {
          input2 =
            '<input  aria-label="' +
            v +
            '" name="' +
            object +
            "[" +
            v +
            ']" type="hidden" class="form-control" value="0">';
        } else if (v == "id ") {
          input2 =
            '<input  aria-label="' +
            v +
            '" name="' +
            object +
            "[" +
            v +
            ']" type="hidden" class="form-control" value="0">';
        } else {

          input2 = `<div class="` + alt_class + `">
                      <div class="ps-1 py-2">` + label_title + `</div>
                      <div class="col-sm-12">
                        <div class="form-group bmd-form-group">
                          <input type="number" aria-label="` + v + `" name="` + object + `[` + v + `]" class="form-control">
                        </div>
                      </div>
                    </div>`
        }
        break;
      case "date":

        input2 = `<div class="` + alt_class + `">
                      <div class="ps-1 py-2">` + label_title + `</div>
                      <div class="col-sm-12">
                        <div class="form-group">
                          <input type="text" aria-label="` + v + `" name="` + object + `[` + v + `]" class="form-control datepicker">
                        </div>
                      </div>
                    </div>`
        break;
      case "naive_datetime":

        input2 = `<div class="` + alt_class + `">
                      <div class="ps-1 py-2">` + label_title + `</div>
                      <div class="col-sm-12">
                        <div class="form-group bmd-form-group">
                          <input type="text" aria-label="` + v + `" name="` + object + `[` + v + `]" class="form-control datetimepicker">
                        </div>
                      </div>
                    </div>`
        break;
      default:
        // code block
        if (v == "id" || v.includes("_id")) {
          input2 =
            '<input  aria-label="' +
            v +
            '" name="' +
            object +
            "[" +
            v +
            ']" type="hidden" class="form-control" value="0">';
        } else {

          input2 = `<div class="` + alt_class + `">
                      <div class="ps-1 py-2">` + label_title + `</div>
                      <div class="col-sm-12">
                        <div class="form-group bmd-form-group">
                          <input type="text" aria-label="` + v + `" name="` + object + `[` + v + `]" class="form-control">
                        </div>
                      </div>
                    </div>`
        }
    }
    if (typeof qv == "object") {
      var selections = [];

      if (qv.selection != null) {
        var live_search = ""
        var multiple = ""
        if (qv.live_search != null) {
          if (qv.live_search) {
            live_search = `data-live-search="true"`
          }
        }
        if (qv.multiple != null) {
          if (qv.multiple) {
            multiple = "multiple"
          }
        }
        $(qv.selection).each(function(index, selection) {
          var name;

          var vall;
          if (typeof selection == "object") {
            name = selection.name;
            vall = selection.id;
          } else {
            name = selection;
            vall = selection;
          }
          selections.push('<option value="' + vall + '">' + name + "</option>");
        });



        input2 = `<div class="` + alt_class + `">
                      <div class="ps-1 py-2">` + label_title + `</div>
                      <div class="col-sm-12">
                        <div class="form-group">
                         <select ` + multiple + ` ` + live_search + `aria-label="` + v + `" name="` + object + `[` + v + `]" class="form-control selectpicker" >
                         ` + selections.join("") + `
                         </select>
                        </div>
                      </div>
                    </div>`
      }


      if (qv.binary) {


        input2 = `<div class="` + alt_class + `">
                      <div class="ps-1 py-2">` + label_title + `</div>
                      <div class="col-sm-12">
                        <div class="form-group bmd-form-group">
                          <textarea rows=12 cols=12 aria-label="` + v + `" name="` + object + `[` + v + `]" class="form-control"></textarea>
                        </div>
                      </div>
                    </div>`
      }
      if (qv.code) {

        input2 = `<div class="row">
                      <label class="col-sm-3 col-form-label text-end">` + label_title + `</label>
                      <div class="col-sm-9">
                        <div class="form-group bmd-form-group">
                          <textarea rows=4 cols=12 aria-label="` + v + `" name="` + object + `[` + v + `]" class="form-control code"></textarea>
                        </div>
                      </div>
                    </div>`
      }
      if (qv.checkboxes != null) {
        var checkboxes = [];

        qv.checkboxes.sort(function(b, a) {
          return b.name.localeCompare(a.name);
        })

        $(qv.checkboxes).each((i, checkbox) => {
          var c =
            `
                    <div class="form-check">
                      <label class="text-capitalize">
                        <input aria-label="` + v + `" class="form-check-input many_2_many" type="checkbox" name="` +
            object +
            "[" +
            v +
            `][` +
            checkbox.id +
            `]"  value="true"> ` +
            checkbox.name +
            `
                        <span class="form-check-sign">
                          <span class="check"></span>
                        </span>
                      </label>
                    </div>`;
          checkboxes.push(c);
        });

        input2 = `<div class="row">
                      <label class="col-sm-2 col-form-label text-end">` + label_title + `</label>
                      <div class="col-sm-8">
                        <div class="form-group bmd-form-group">
                          ` + checkboxes.join("") + `
                        </div>
                      </div>
                    </div>`
      }

     
      if (qv.upload) {


        input2 = `<div class="` + alt_class + `">
                      <div class="pb-1 pt-1 ps-1 text-start">` + label_title + `</div>
                      <div class="col-sm-12">
                        
                        <img style="display: none;" id="myImg" src="#" alt="your image" width=300>
                          <input style="padding-top: 2vh;" type="file" aria-label="` + v + `" name="` + object + `[` + v + `]" class="">
                        
                      </div>
                    </div>`
      }

      if (qv.editor) {
        input2 =
          `<div class="` + alt_class + `">
              <div class="form-group bmd-form-group">
              <label class="bmd-label-floating my-2">` +
          label_title +
          `</label>
                  <textarea id="editor1" rows=10 cols=12 aria-label="` +
          v +
          `" name="` +
          object +
          "[" +
          v +
          `]" class="form-control" ></textarea>
              </div>
          </div>`;

        // var editor = new EditorJS('editorjs');
      }
      if (qv.datetime) {

        input2 = `<div class="row">
                      <label class="offset-lg-1 col-sm-3 col-form-label text-start">` + label_title + `</label>
                      <div class="col-sm-6">
                        <div class="form-group bmd-form-group">
                          <input type="datetime-local" aria-label="` + v + `" name="` + object + `[` + v + `]" class="form-control datepicker">
                        </div>
                      </div>
                    </div>`
      }
      if (qv.date) {

        input2 = `<div class="row">
                      <label class="offset-lg-1 col-sm-3 col-form-label text-start">` + label_title + `</label>
                      <div class="col-sm-6">
                        <div class="form-group bmd-form-group">
                          <input type="date" aria-label="` + v + `" name="` + object + `[` + v + `]" class="form-control datepicker">
                        </div>
                      </div>
                    </div>`
      }
      if (qv.alias) {

        var assoc_val = v.split(".")
        console.log('not sure if onclick')
        if (qv.onClickFn != null) {

          if (assoc_val.length == 2) {

            input2 = `<div class="` + alt_class + `">
                        <div class="pb-1 pt-1 ps-1 text-start">` + label_title + `</div>
                        <div class="row gx-0">
                          <div class="col-10">
                            <div class="form-group bmd-form-group">
                              <input type="text" aria-label="` + v + `" name="` + object + `[` + assoc_val[0] + `][` + assoc_val[1] + `]" class="form-control">
                            </div>
                          </div>
                          <div class="col-2">
                            <div class="btn btn-outline-primary" onclick="` + qv.onClickFn + `">Change</div>
                          </div>
                        </div>
                      </div>`
          }

          if (assoc_val.length == 3) {

            input2 = `<div class="` + alt_class + `">
                        <div class="pb-1 pt-1 ps-1 text-start">` + label_title + `</div>
                        <div class="row">
                          <div class="col-10">
                            <div class="form-group bmd-form-group">
                              <input type="text" aria-label="` + v + `" name="` + object + `[` + assoc_val[0] + `][` + assoc_val[1] + `][` + assoc_val[2] + `]" class="form-control">
                            </div>
                          </div>
                          <div class="col-2">
                            <div class="btn btn-outline-primary" onclick="` + qv.onClickFn + `">Change</div>
                          </div>
                        </div>
                      </div>`
          }

        } else {
          if (assoc_val.length == 2) {

            input2 = `<div class="` + alt_class + `">
                              <div class="pb-1 pt-1 ps-1 text-start">` + label_title + `</div>
                              <div class="row">
                                <div class="col-12">
                                  <div class="form-group bmd-form-group">
                                    <input type="text" aria-label="` + v + `" name="` + object + `[` + assoc_val[0] + `][` + assoc_val[1] + `]" class="form-control">
                                  </div>
                                </div>
                               
                              </div>
                            </div>`

            if (qv.binary) {

              input2 = `<div class="` + alt_class + `">
                                        <div class="ps-1 py-2">` + label_title + `</div>
                                        <div class="col-sm-12">
                                          <div class="form-group bmd-form-group">
                                            <textarea rows=4 cols=12 aria-label="` + v + `"  name="` + object + `[` + assoc_val[0] + `][` + assoc_val[1] + `]" class="form-control"></textarea>
                                          </div>
                                        </div>
                                      </div>`



            }

            if (qv.editor) {

              input2 = `<div class="` + alt_class + `">
                                        <div class="ps-1 py-2">` + label_title + `</div>
                                        <div class="col-sm-12">
                                          <div class="form-group bmd-form-group">
                                            <textarea id="editor1" rows=10 cols=12 aria-label="` + v + `"  name="` + object + `[` + assoc_val[0] + `][` + assoc_val[1] + `]" class="form-control"></textarea>
                                          </div>
                                        </div>
                                      </div>`



            }
          }
          if (assoc_val.length == 3) {

            input2 = `<div class="` + alt_class + `">
                              <div class="pb-1 pt-1 ps-1 text-start">` + label_title + `</div>
                              <div class="row">
                                <div class="col-12">
                                  <div class="form-group bmd-form-group">
                                    <input type="text" aria-label="` + v + `" name="` + object + `[` + assoc_val[0] + `][` + assoc_val[1] + `][` + assoc_val[2] + `]" class="form-control">
                                  </div>
                                </div>
                               
                              </div>
                            </div>`
          }
        }


      }
      if (qv.hidden) {

        if (v.includes(".")) {

          var assoc_val = v.split(".")
          input2 =
            '<input type="hidden" aria-label="' +
            v +
            '" name="' +
            object +
            '[' + assoc_val[0] + '][' + assoc_val[1] + ']"  aria-value="' + qv.data + '">';
        } else {

          input2 =
            '<input type="hidden" aria-label="' +
            v +
            '" name="' +
            object +
            "[" +
            v +
            ']"  aria-value="' + qv.data + '">';
        }

      }

    }

    return input2;
  },
  appendInputs(xv, cols, j, object) {
    $(cols).each(function(qi, qv) {
      var v;
      if (typeof qv == "object") {
        v = qv.label;
      } else {
        v = qv;
      }
      var input = "";
      var input2 = "";
      input2 = phxApp_.generateInputs(j, v, object, qv);
      if (typeof qv == "object") {
        var selections = [];
        if (qv.binary) {} else {
          if (qv.sub != null) {
            // here insert a smaller form inputs?
            // run the form submission first,
            // get the primary id and stuff it back to parent form
            var subModule = qv.sub.moduleName;
            var subLink = qv.sub.link;
            var customCols = qv.sub.customCols;
            $.ajax({
              url: "/api/webhook?scope=gen_inputs",
              dataType: "json",
              async: false,
              data: {
                module: subModule
              }
            }).done(function(j) {
              var cols = Object.keys(j);

              if (customCols != null) {
                if (customCols.length > 0) {

                  cols = customCols;
                }
              }

              var combo = [];
              $(cols).each((i, col) => {
                var v;
                if (typeof col == "object") {
                  v = col.label;
                } else {
                  v = col;
                }
                var input3 = "";
                input3 = phxApp_.generateInputs(j, v, subLink, col);
                combo.push(input3);
              });

              input2 =
                input2 +
                `<div class="row subform" style="display: none;"><div class="offset-1 col-sm-9">` +
                combo.join("") +
                `</div></div>`;
            }).fail(function(e) {
              if (e.status == 403) {
                memberApp_.logout()
              }

              phxApp_.notify("Not Added!", {
                type: "danger"
              });
            });
          }
        }
      }

      // input into a different panels?
      $(xv).append(input2);
    });

  },
  form_new(id, data, customCols, postFn, onDrawFn) {
    console.log(data)

    var dataSource =
      window.phoenixModels.filter((v, i) => {
        return v.tableSelector == id
      })[0]

    var default_selector = "#mySubModal"
    if (data.modalSelector != null) {
      default_selector = data.modalSelector
    }

    if (customCols == null) {
      customCols = dataSource.customCols
    }
    var form =
      `<form style="" class="with_mod" id="` +
      dataSource.link +
      `"  module="` +
      dataSource.moduleName +
      `">
      </form>`;
    $(default_selector)
      .find(".modal-title")
      .html("Create  New " + dataSource.moduleName);
    $(default_selector).find(".modal-body").html(form);
    phxApp_.createForm({
      ...{ id: 0 },
      ...data
    }, dataSource.table, customCols, postFn, onDrawFn);

    $(default_selector).modal('show');

  },
  createForm(dtdata, table, customCols, postFn, onDrawFn) {
    $(".with_mod").each(function(i, xv) {
      // var xv = form ;
      $(xv).html(``);

      var mod = $(this).attr("module");
      var object = $(this).attr("id");

      $.ajax({
        async: false,
        url: "/api/webhook?scope=gen_inputs",
        dataType: "json",
        data: {
          module: mod
        }
      }).done(function(j) {
        var cols = Object.keys(j);


        if (customCols != null) {
          // convert this to a ... tab panels...

          if (typeof customCols[0] === 'object' && customCols[0] !== null) {
            console.log("has multi list," + customCols.length)
            // insert the tabs?

            $(xv).customHtml(`<input type="hidden" name="_csrf_token"  value="">
                            <div class="row">
                              <div class="col-12 col-lg-4">
                                <ul class="nav nav-pills flex-column form_nav">
                                 
                               
                                </ul>

                              </div>
                              <div class="col-12 col-lg-8 p-4 pt-lg-0 px-lg-4 " id="form_panels">

                              </div>
                            </div>

                        `)


            // function formNavClick(index) {
            //   $(".form_nav .nav-link").removeClass("active")
            //   $(".nav-link[aria-index='" + index + "']").toggleClass("active")
            //   $(".fp").addClass("d-none")
            //   $("#panel_" + index).toggleClass("d-none")
            // }
            $(customCols).each((i, v) => {
              if (i == 0) {
                $(xv).find(".form_nav").customAppend(`
                                   <li class="nav-item">
                                      <a class="active nav-link fnc" aria-index="` + i + `" href="javascript:void(0);"  >` + v.name + `</a>
                                    </li>
                          `)
              } else {

                $(xv).find(".form_nav").customAppend(`
                                   <li class="nav-item">
                                      <a class="nav-link fnc" aria-index="` + i + `" href="javascript:void(0);"  >` + v.name + `</a>
                                    </li>
                          `)
              }

              $(xv).find(".fnc").each((i, v) => {

                v.onclick = () => {
                  var index = $(v).attr("aria-index")
                  $(".form_nav .nav-link").removeClass("active")
                  $(".nav-link[aria-index='" + index + "']").toggleClass("active")
                  $(".fp").addClass("d-none")
                  $("#panel_" + index).toggleClass("d-none")
                }

              })
              // insert the panels
              if (i == 0) {
                $(xv).find("#form_panels").customAppend(`<div class="fp row" id="panel_` + i + `"></div>`)

              } else {
                $(xv).find("#form_panels").customAppend(`<div class="fp row d-none"  id="panel_` + i + `"></div>`)

              }
              $(xv).find("#panel_" + i).customAppend(`<div class="col-lg-12"><b class="pb-4">` + v.name + `</b></div>`);
              phxApp_.appendInputs($(xv).find("#panel_" + i), v.list, j, object)
            })



          } else {
            cols = customCols;
            $(xv).append(`<input type="hidden" name="_csrf_token"  value="">`)
            phxApp_.appendInputs(xv, cols, j, object)
            console.log(cols.join("','"));
          }


        } else {
          cols =
            cols.filter((v, i) => {
              return v != "inserted_at"
            })
          cols =
            cols.filter((v, i) => {
              return v != "updated_at"
            })
          phxApp_.appendInputs(xv, cols, j, object)
          console.log(cols.join("','"));
        }

        $($(xv).find("select")).on("change", function() {
          var val = $(this).val();
          var sf = $($(this).closest(".subform")).length;
          console.log(val);
          if (sf == 0) {

            if (val == 0) {
              $(".subform").fadeIn();
            } else {
              $(".subform").hide();
            }
          }
        });

        function btnSubm() {
          if ($("#myModal .modal-dialog").hasClass("modal-lg")) {
            $("#myModal .modal-dialog").toggleClass("modal-lg")
          }
          var formData = new FormData($(xv).closest("form")[0]);
          $(xv)
            .find("input[type='checkbox']")
            .each((zi, zv) => {
              $(zv).val($(zv).prop("checked"));

              formData.append(
                object + "[" + $(zv).attr("aria-label") + "]",
                $(zv).prop("checked")
              );
            });

          $(xv)
            .find("textarea")
            .each((zi, zv) => {
              formData.append(
                object + "[" + $(zv).attr("aria-label") + "]",
                $(zv).val()
              );
            });
          // console.log(formData);
          var failed_inputs =
            $(".with_mod").closest("form").find("input").filter((i, v) => {
              console.log("checking vaidity")
              console.log(v)
              return v.checkValidity() == false
            })
          console.log(failed_inputs);
          if (failed_inputs.length > 0) {
            failed_inputs.map((v, i) => {
              phxApp_.notify("This input: " + $(i).attr("placeholder") + " is not valid!", {
                type: "danger"
              });

            })

          } else {
            var csrfToken = phxApp_.csrf_(true)
            $.ajax({
                url: "/api/" + object,
                dataType: "json",
                headers: {
                  "Authorization": "Basic " + (phxApp_.user != null ? phxApp_.user.token : null),
                  'X-CSRF-Token': csrfToken
                },
                method: "POST",
                enctype: "multipart/form-data",
                processData: false, // tell jQuery not to process the data
                contentType: false,
                data: formData
              })
              .done(function(j) {
                phxApp_.notify("Added!", {
                  type: "success"
                });
                $("#mySubModal").modal("hide");
                $("#sideModal").modal("hide");
                if (table != null) {
                  console.log("redrawing table.. " + window.currentSelector);
                  console.log(object)
                  console.log(window.currentSelector)
                  var tarMods = window.phoenixModels.filter((v, i) => {
                    return v.moduleName == object && v.tableSelector == window.currentSelector
                  })

                  tarMods.forEach((tarMod, i) => {

                    try {
                      window.prev_page = tarMod.table.page()
                      tarMod.reload();
                    } catch (e) {
                      console.log("cant find the table")

                    }
                  })

                }
                if (postFn != null) {
                  if (dtdata.xparams != null) {

                    postFn(dtdata.xparams);
                  } else {

                    postFn(j);
                  }
                }


              })

              .fail(function(e) {
                    alert("!")
                if (e.status == 403) {
                  memberApp_.logout()
                }
                try {
                  console.log(e.responseJSON.status);
                  phxApp_.notify("Not Added! reason: " + e.responseJSON.status, {
                    type: "danger"
                  });
                } catch (ee) {
                  phxApp_.notify("Not Added!", {
                    type: "danger"
                  });
                }
              });
          }

        };
        var row = document.createElement("div")
        row.className = "row"

        var col_lg_12 = document.createElement("div")
        col_lg_12.className = "pt-4 col-lg-12"
        row.append(col_lg_12)

        try {
          var ck_editor = CKEDITOR.replace("editor1", {
            height: 500,
            on: {
              instanceReady: function() {
                this.document.appendStyleSheet('/css/bootstrap.min.css');
              }
            }
          });
          CKEDITOR.config.allowedContent = true;
          CKEDITOR.config.removeButtons = 'Image';
          CKEDITOR.instances.editor1.on("change", function() {
            var data = CKEDITOR.instances.editor1.getData();
            $(CKEDITOR.instances.editor1.element["$"]).val(data);
          });

          ck_editor.addCommand("mySimpleCommand", {
            exec: function(edt) {
              try {
                callStoredMedia(CKEDITOR.instances.editor1);
              } catch (e) {

              }
            }
          });
          ck_editor.ui.addButton('SuperButton', {
            label: "Click me",
            command: 'mySimpleCommand',
            toolbar: 'insert',
            icon: '/images/image-solid.svg'
          });

        } catch (e) {
          console.log("no editor");
        }

        var submit_btn = phxApp_.formButton(

          {
            iconName: "check",
            color: "primary subm",
            name: "Submit"

          }, {},
          btnSubm

        );
        col_lg_12.append(submit_btn)

        if ($(xv).find(".subm").length == 0) {
          $(xv).append(row);
        }

        console.info(dtdata)
        phxApp_.repopulateFormInput(dtdata, xv);


      }).fail(function(e) {
        alert("!!!")
        if (e.status == 403) {
          memberApp_.logout()
        }
        console.log(e.responseJSON.status);
        phxApp_.notify("Not Added!", {
          type: "danger"
        });
      });
      // return xv;
    });

    if (onDrawFn != null) {

      onDrawFn()
    }
  },
  submitFormData(selector, url, postFn, xparams) {

    if ($("#myModal .modal-dialog").hasClass("modal-lg")) {
      $("#myModal .modal-dialog").toggleClass("modal-lg")
    }
    var object = url
    var xv = $(selector)[0]
    var formData = new FormData(xv);

    $(xv)
      .find("input[type='checkbox']")
      .each((zi, zv) => {
        $(zv).val($(zv).prop("checked"));

        formData.append(
          object + "[" + $(zv).attr("aria-label") + "]",
          $(zv).prop("checked")
        );
      });
    console.log(formData);
    $.ajax({
        url: "/api/" + object,
        dataType: "json",
        method: "POST",
        headers: {
          "Authorization": "Basic " + (phxApp_.user != null ? phxApp_.user.token : null),
        },
        enctype: "multipart/form-data",
        processData: false, // tell jQuery not to process the data
        contentType: false,
        data: formData,
        xhr: function() {
          $("#helper").fadeIn();
          //Get XmlHttpRequest object
          var xhr = $.ajaxSettings.xhr();
          //Set onprogress event handler
          xhr.upload.onprogress = function(data) {
            var perc = Math.round((data.loaded / data.total) * 100);
            $("[role='progressbar']").css("width", perc + "%");
            $("#helper").text(perc + "%");
          };
          return xhr;
        },
        error: function(e) {
          console.error("Error has occurred while uploading the media file.");

        }
      })
      .done(function(j) {
        phxApp_.notify("Added!", {
          type: "success"
        });

        try {
          phxApp_.reinit();
          $("#myModal").modal('hide')
        } catch (e) {

        }

        try {
          if (postFn != null) {
            postFn(xparams);
          }
        } catch (e) {

        }

        phxApp_.hide()
      })
      .fail(function(e) {
        if (e.status == 403) {
          memberApp_.logout()
        }

        try {
          console.log(e.responseJSON.status);
          phxApp_.notify("Not Added! reason: " + e.responseJSON.status, {
            type: "danger"
          });

        } catch (ee) {
          phxApp_.notify("Not Added! reason: 404", {
            type: "danger"
          });

        }
      });
  },
  formButton(options, fnParams, onClickFunction) {
    var default_options = {
      iconName: "fa fa-check",
      color: "btn btn-primary",
      onClickFunction: null,
      fnParams: null,
      name: "Submit",
      tooltipText: "Hints"
    }
    var keys =
      Object.keys(default_options)
    keys.forEach((v, i) => {
      this[v] = default_options[v]
    })
    keys.forEach((v, i) => {
      if (options[v] != null) {
        this[v] = options[v]
      }
    })

    var button = document.createElement("button");
    button.setAttribute("type", "button");
    button.setAttribute("data-bs-toggle", "tooltip");
    button.setAttribute("data-bs-original-title", "");
    button.setAttribute("data-bs-placement", "left");

    button.setAttribute("class", "btn btn-" + this.color + " btn-sm");
    button.setAttribute("title", this.tooltipText);
    var i = document.createElement("i");
    i.className = this.iconName;

    button.append(i);
    var nameSpan = document.createElement("span");
    if (this.name == undefined) {
      this.name = "";
    } else {
      nameSpan.setAttribute("style", "padding: 0 10px;");
    }
    nameSpan.innerHTML = this.name;
    button.append(nameSpan);
    var div = document.createElement("div");
    div.className = "ripple-container";
    button.append(div);
    button.style = "margin-left: 10px;";
    if (onClickFunction != null) {
      try {
        button.id = this.fnParams.dtdata.id;
      } catch (e) {
        console.log("dont hav id in fnParams");
      }
      button.onclick = function() {

        // this maybe from a grid view, that uses div
        if ($($(button).closest("tr")).attr("aria-index") == null) {
          fnParams.index = parseInt($($(button).closest("div")).attr("aria-index"))
        } else {
          fnParams.index = parseInt($($(button).closest("tr")).attr("aria-index"))
        }

        // parseInt($($(button).closest("tr")).attr("aria-index"));
        fnParams.row = $(button).closest("tr");
        fnParams.tbody = $(button).closest("tbody");
        onClickFunction(fnParams);
      };
    }
    return button;
  },
  groupedFormButton(name, color, button_list, fnParams) {

    var ref = phxApp_.makeid(6)
    var div = document.createElement("div")
    div.setAttribute("class", "btn-group")
    div.setAttribute("role", "group")
    div.setAttribute("aria-label", "Button group with nested dropdown")
    div.setAttribute("style", "margin-left: 10px;")

    var button = document.createElement("button")
    button.setAttribute("type", "button")
    button.setAttribute("class", "manage btn btn-sm btn-" + color)
    button.innerHTML = name
    div.append(button)

    var div2 = document.createElement("div")
    div2.setAttribute("class", "btn-group")
    div2.setAttribute("role", "group")
    var button2 = document.createElement("button")
    button2.setAttribute("id", ref)
    button2.setAttribute("type", "button")
    button2.setAttribute("class", "btn btn-sm btn-" + color + " dropdown-toggle")
    button2.setAttribute("data-bs-toggle", "dropdown")
    button2.setAttribute("aria-haspopup", "true")
    button2.setAttribute("aria-expanded", "false")
    div2.append(button2)
    var div3 = document.createElement("div")
    div3.setAttribute("class", "dropdown-menu")
    div3.setAttribute("aria-labelledby", ref)
    $(button_list).each((i, v) => {
      if (v.fnParams != null) {

        v.fnParams.dataSource = fnParams.dataSource
      } else {
        v.fnParams = fnParams
      }
      var child = phxApp_.childGroupedFormButton(v.name, v.onClickFunction, v.fnParams)

      div3.append(child)
    })
    div2.append(div3)
    div.append(div2)
    return div;

  },
  childGroupedFormButton(name, onClickFunction, fnParams) {
    var button = document.createElement("a")
    button.setAttribute("class", "dropdown-item")
    button.setAttribute("href", "javascript:void(0);")
    button.innerHTML = name
    if (onClickFunction != null) {
      // console.log(fnParams)
      try {
        button.id = fnParams.dtdata.id;
      } catch (e) {
        // console.log("dont hav id in fnParams");
      }
      button.onclick = function() {
        fnParams.index = parseInt($($(button).closest("tr")).attr("aria-index"));
        // console.log("fnparam index")
        // console.log(fnParams.index)
        if (fnParams.index > -1) {} else {
          fnParams.index = parseInt($($(button).closest(".card-footer")).attr("aria-index"));
        }
        // console.log($($(button).closest(".card-footer")).attr("aria-index"))
        // console.log(fnParams.index)
        // console.log($(button).closest(".card-footer"))
        fnParams.row = $(button).closest("tr");
        onClickFunction(fnParams);
      };
    }

    return button
  },
  makeid(length) {
    var result = "";
    var characters =
      "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";
    var charactersLength = characters.length;
    for (var i = 0; i < length; i++) {
      result += characters.charAt(Math.floor(Math.random() * charactersLength));
    }
    return result;
  },
  appendDtButtons(table_selector, parent_container_selector, data) {

    $(table_selector).closest(parent_container_selector).find(".module_buttons").customHtml(`
                <button type="submit" onclick="toggleView('` + table_selector + `')" class="btn btn-fill btn-round btn-primary" data-href="" data-module="" data-ref="">
                <i class="fa fa-th-large"></i></button>
                <button type="submit" onclick="phxApp.reinit()" class="btn btn-fill btn-round btn-primary" data-href="" data-module="" data-ref="">
                <i class="fa fa-circle-notch
      "></i></button>
                <button type="submit" class="btn btn-fill btn-round btn-primary"  data-href="" data-module="add_new" data-ref=""><i class="fa fa-plus"></i></button>
                `);

    var nbutton = $(table_selector).closest(parent_container_selector).find(".module_buttons button[data-module='add_new']");
    try {
      nbutton[0].onclick = function() {
        window.currentSelector = table_selector;
        console.log("sub sub table data")
        console.log(data)
        form_new(table_selector, data)
      }

    } catch (e) {

    }

  },
  appendRowDtButtons(dataSource, index) {


    $(dataSource.buttons).each((i, params) => {




      if (params.buttonType != null) {
        if (params.buttonType == "grouped") {
          console.log("creating grouped...button...")
          params.fnParams.dataSource = dataSource;
          params.fnParams.aParams = dataSource.data;
          var buttonz = phxApp_.groupedFormButton(
            params.name,
            params.color,
            params.buttonList,
            params.fnParams
          );
          $(dataSource.tableSelector).closest(".table-responsive").find(".gd[aria-index='" + index + "']").removeClass("d-none");
          $(dataSource.tableSelector).closest(".table-responsive").find(".gd[aria-index='" + index + "']").append(buttonz);

        } else {
          params.fnParams.dataSource = dataSource;
          params.fnParams.aParams = dataSource.data;
          var buttonz = phxApp_.formButton({
              iconName: params.iconName,
              color: params.color,
              name: params.name
            },
            params.fnParams,
            params.onClickFunction);

          $(dataSource.tableSelector).closest(".table-responsive").find(".gd[aria-index='" + index + "']").removeClass("d-none");
          $(dataSource.tableSelector).closest(".table-responsive").find(".gd[aria-index='" + index + "']").append(buttonz);


          // $("td:eq(" + lastCol + ")", row).append(buttonz);
        }
      } else {

        console.log("appending gd buttons : " + i)
        params.fnParams.dataSource = dataSource;
        params.fnParams.aParams = dataSource.data;
        var buttonz = phxApp_.formButton({
            iconName: params.iconName,
            color: params.color,
            name: params.name,
            tooltipText: params.tooltipText
          },
          params.fnParams,
          params.onClickFunction);

        // convert them into a 

        $(dataSource.tableSelector).closest(".table-responsive").find(".gd[aria-index='" + index + "']").removeClass("d-none")
        $(dataSource.tableSelector).closest(".table-responsive").find(".gd[aria-index='" + index + "']").append(buttonz);

      }
    });

  },
  getTableData(dataSourcee, length, onCompleteFn) {
    var len = 100;
    if (length != null) {
      len = length;
    }
    var keys = Object.keys(dataSourcee.data);
    var xparams = [];
    $(keys).each((i, k) => {
      xparams.push("&" + k + "=" + dataSourcee.data[k]);
    });
    $.ajax({
      async: false,
      url: "/api/" + dataSourcee.link + "?foo=bar" + xparams.join(""),
      data: {
        draw: "1",
        order: {
          0: {
            column: "0",
            dir: "desc"
          }
        },
        columns: {
          0: {
            data: "id"
          }
        },
        length: len,
        start: 0
      }
    }).done(function(j) {
      $(j.data).each((i, dtdata) => {
        var added = $(dataSourcee.allData).filter(function(i, v) {
          return v.id == dtdata.id;
        });
        if (added.length == 0) {
          dataSourcee.allData.push(dtdata);
        }
      });

      if (onCompleteFn != null) {
        onCompleteFn()
      }

    }).fail(function(e) {
      if (e.status == 403) {
        memberApp_.logout()
      }

      phxApp_.notify("Not Added!", {
        type: "danger"
      });
    });
  },
    copyToClipboard(text) {
        navigator.clipboard.writeText(text)
          .then(() => {
            console.log('Text copied to clipboard:', text);
            alert('Text copied to clipboard!');
          })
          .catch(err => {
            console.error('Could not copy text: ', err);
            alert('Could not copy text: ' + err);
          });
      },
  populateTableData(dataSourcee, length, onCompleteFn) {
    this.getTableData(dataSourcee, length, onCompleteFn)
  },
  populateGridView(dataSource) {
    console.log(dataSource)
    var grid_class = "col-12 col-lg-3 xc"

    try {

      if (dataSource.data.grid_class != null) {
        grid_class = dataSource.data.grid_class + " xc"
      }
    } catch (e) {

    }
    // var xcard = dataSource.xcard
    $(dataSource.tableSelector).closest(".dataTables_wrapper").find(".grid_view").html("<div></div>")

    var alis = []
    dataSource.table.data().length
    for (i = 0, j = dataSource.table.data().length; i < j; i++) {
      dataSource.table.data()[i].index = i
      alis.push(dataSource.table.data()[i])
    }

    var i, j, chunk = 12;
    var temparray = [];
    for (i = 0, j = alis.length; i < j; i += chunk) {
      temparray.push(alis.slice(i, i + chunk))
    }

    temparray.forEach((row, i) => {

      var parentDiv = document.createElement("div")
      parentDiv.setAttribute("class", "row gx-0 ")

      row.forEach((pv, pi) => {
        var data = pv

        var div = document.createElement("div")
        div.setAttribute("class", grid_class)
        var card = document.createElement("div")
        card.setAttribute("id", data.id)
        card.className = "card-footer gd d-none"
        div.data = pv
        // div.className = "card-footer"
        div.data.dataSource = dataSource
        if (data.index != null) {
          card.setAttribute("aria-index", data.index)
        };
        div.appendChild(card)
        parentDiv.appendChild(div)
      })

      // console.log(cards)
      $(dataSource.tableSelector).closest(".dataTables_wrapper").find(".grid_view").append(parentDiv)
      // here can start do the formating

    })

    $(dataSource.tableSelector).closest(".table-responsive").find(" .gd").each((i, v) => {
      var id = $(v).attr("aria-index")
      console.log("there is index... d" + i)

      phxApp_.appendRowDtButtons(dataSource, id)
    })

  },
  populateTable(dataSource) {
    var custSorts = [
      [0, "desc"]
    ]
    var location = "/api/"
    if (dataSource.data.host != null) {
      location = dataSource.data.host + "/api/"
    }
    var custPageLength = 10
    var custDom = `

    <"row align-items-center"
      <"col-lg-4"l>
      <"gap-2 col-lg-8 text-center 
        module_buttons 
        d-flex justify-content-lg-end 
        justify-content-center py-2 py-lg-0">
    >
    <"row grid_view d-block d-lg-none">
    <"list_view d-lg-block d-none"t>
    <"row transform-75 p-4"
      <"col-lg-6"i><"col-lg-6"p>
    >

    `
    if (dataSource.data.dom != null) {
      custDom = dataSource.data.dom
    }
    if (dataSource.data.sorts != null) {
      custSorts = dataSource.data.sorts
    }
    if (dataSource.data.pageLength != null) {
      custPageLength = dataSource.data.pageLength
    }

    var tr = document.createElement("tr");
    var ftr = document.createElement("tr");
    $(dataSource.columns).each(function(i, v) {
      var td = document.createElement("td");
      td.innerHTML = v.label;
      tr.append(td);
    });
    $(dataSource.columns).each(function(i, v) {
      var td = document.createElement("td");
      ftr.append(td);
    });

    console.info(custSorts)

    $(dataSource.tableSelector).find("thead").append(tr);
    $(dataSource.tableSelector).find("tfoot").html(ftr);
    console.log(dataSource.data);
    var keys = Object.keys(dataSource.data);
    var xparams = [];
    $(keys).each((i, k) => {
      if (!["modalSelector", "sorts", "dom", "footerFn", "rowFn", "preloads", "grid_class"].includes(k)) {
        xparams.push("&" + k + "=" + dataSource.data[k]);
      }
      if (["preloads"].includes(k)) {
        xparams.push("&" + k + "=" + JSON.stringify(dataSource.data[k]));
      }
      if (["additional_join_statements"].includes(k)) {
        xparams.push("&" + k + "=" + JSON.stringify(dataSource.data[k]));
      }

    });

    var table_selector = dataSource.tableSelector;

    var table = $(table_selector).DataTable({

      pageLength: custPageLength,
      processing: true,
      responsive: true,
      serverSide: true,
      ajax: {
        url: location + dataSource.link + "?foo=bar" + xparams.join("")
      },
      columns: dataSource.columns,
      lengthMenu: [8, 10, 12, 25, 50, 100],
      rowCallback: function(row, dtdata, index) {
        console.log("dt rowcallback index " + index)
        var added = $(dataSource.allData).filter(function(i, v) {
          return v.id == dtdata.id;
        });
        if (added.length == 0) {
          dataSource.allData.push(dtdata);
        }
        $(row).addClass("d-none")
        $(row).attr("aria-index", index);
        lastCol = $(row).find("td").length - 1;
        row.dataset.dtdata = JSON.stringify(dtdata)
        ColumnFormater.datetime(row, dtdata, dataSource)
        ColumnFormater.img(row, dtdata, dataSource)
        ColumnFormater.bool(row, dtdata, dataSource)
        ColumnFormater.float(row, dtdata, dataSource)
        ColumnFormater.child(row, dtdata, dataSource)
        ColumnFormater.json(row, dtdata, dataSource)
        ColumnFormater.subtitle(row, dtdata, dataSource)
        ColumnFormater.progress(row, dtdata, dataSource)
        ColumnFormater.custom(row, dtdata, dataSource)
        $("td:eq(" + lastCol + ")", row).attr("class", "td-actions text-end");
        $("td:eq(" + lastCol + ")", row).html("");
        $(dataSource.buttons).each((i, params) => {
          if (params.buttonType != null) {
            if (params.buttonType == "grouped") {
              console.log("creating grouped...button...")
              params.fnParams.dataSource = dataSource;
              params.fnParams.aParams = dataSource.data;
              var buttonz = phxApp_.groupedFormButton(
                params.name,
                params.color,
                params.buttonList,
                params.fnParams
              );
              $("td:eq(" + lastCol + ")", row).append(buttonz);

            } else {
              params.fnParams.dataSource = dataSource;
              params.fnParams.aParams = dataSource.data;
              var buttonz = phxApp_.formButton({
                  iconName: params.iconName,
                  color: params.color,
                  name: params.name
                },
                params.fnParams,
                params.onClickFunction);
              $("td:eq(" + lastCol + ")", row).append(buttonz);
            }
          } else {

            params.fnParams.dataSource = dataSource;
            params.fnParams.aParams = dataSource.data;
            var buttonz = phxApp_.formButton({
                iconName: params.iconName,
                color: params.color,
                name: params.name,
                tooltipText: params.tooltipText
              },
              params.fnParams,
              params.onClickFunction
            );
            $("td:eq(" + lastCol + ")", row).append(buttonz);
          }
        });
        if (dataSource.data.rowFn != null) {
          dataSource.data.rowFn(row, dtdata, index)
        }
      },
      footerCallback: function(row, data, start, end, display) {
        if (dataSource.data != null) {
          if (dataSource.data.footerFn != null) {
            dataSource.data.footerFn(row, data, start, end, display)
          }
        }
      },
      order: custSorts,
      dom: custDom,
      autoWidth: false
    });
    dataSource.table = table

    table.on('preXhr', () => {
      console.log("fetching...")
      // App.show();
    })
    table.on('draw', () => {
      $(".jsv" + dataSource.makeid.id).closest("tr").each((i, v) => {
        var j = dataSource.columns.filter((v, i) => {
          return v.showJson == true;
        })

        j.forEach((xx, xi) => {
          $($(v).find(".jsv" + dataSource.makeid.id)[xi]).jsonViewer(table.data()[i][xx.data], { collapsed: true });
        })

      })


      $(".table tbody tr").each((i, v) => {
        setTimeout(() => {
          $(v).removeClass("d-none")
        }, (10 * i) + 1)
      })

    })
    table.on('xhr', () => {
      // App.hide()
      console.log("fetched")
    })



    var delete_idx =
      window.phoenixModels.findIndex((v, i) => {
        return v.tableSelector == "#subSubTable"
      })
    if (delete_idx != -1) {
      window.phoenixModels.splice(delete_idx, 1)
    }

    var check =
      window.phoenixModels.filter((v, i) => {
        return (v.moduleName == dataSource.moduleName && v.tableSelector == dataSource.tableSelector)

        // return (v.moduleName == dataSource.moduleName)
      })

    if (check.length == 0) {
      window.phoenixModels.push(dataSource)
    } else {
      console.info("the dt already exist, consider reinsert?")


      var delete_idx =
        window.phoenixModels.findIndex((v, i) => {
          return (v.moduleName == dataSource.moduleName && v.tableSelector == dataSource.tableSelector)
        })
      if (delete_idx != -1) {
        window.phoenixModels.splice(delete_idx, 1)
        window.phoenixModels.push(dataSource)
      }
    }

    return table;
  },
  editData(params) {
    console.log("editing data...")
    var dt = params.dataSource;
    window.currentSelector = dt.tableSelector
    var table = dt.table;
    var r = table.row(params.row);
    var rowData = table.data()[params.index]


    var preferedLink;
    if (params.link != null) {
      preferedLink = params.link;
    } else {
      preferedLink = dt.link;
    }
    var default_selector = "#sideModal"
    if ($(default_selector).length == 0) {
      default_selector = "#mySubModal"
    }
    if (dt.data.modalSelector != null) {
      default_selector = dt.data.modalSelector
    }

    function call() {
      console.log(rowData)
      var jj =
        `<form style="margin-top: 0px;" class="with_mod" id="` +
        preferedLink +
        `"  module="` +
        dt.moduleName +
        `"></form>`;
      // r.child(jj).show();

      $(default_selector)
        .find(".modal-title")
        .html("Edit " + dt.moduleName);
      $(default_selector).find(".modal-body").html(jj);
      $(default_selector).modal('show');


      phxApp_.createForm(rowData, table, params.customCols, params.postFn);
      if (params.drawFn != null) {
        params.drawFn()
      }
    }

    if (r.child.isShown()) {
      r.child.hide();
      call();
    } else {
      table.rows().every(function(rowIdx, tableLoop, rowLoop) {
        this.child.hide();
      });
      gParent = this;
      call();
    }
  },
  deleteData(params) {
    console.log("editing data...")
    var dt = params.dataSource;
    window.currentSelector = dt.tableSelector
    var table = dt.table;
    var r = table.row(params.row);
    var rowData = table.data()[params.index]

    $("#myModal").find(".modal-title").html("Confirm delete this data?");
    var confirm_button = phxApp_.formButton("fa fa-check", "outline-danger");
    var csrfToken = this.csrf_()
    confirm_button.onclick = function() {

      console.log(dt)
      $("#myModal").modal("hide");

      $.ajax({
        url: "/api/" + dt.link + "/" + rowData.id,
        dataType: "json",
        headers: {
          "Authorization": "Basic " + (phxApp_.user != null ? phxApp_.user.token : null),
          'x-csrf-token': csrfToken
        },
        method: "DELETE"
      }).done(function(j) {
        $("#myModal").modal("hide");

        phxApp_.notify("Deleted!", {
          type: "info"
        });

        if (table != null) {
          console.log("redrawing table.. " + window.currentSelector);
          console.log(dt.link)
          console.log(window.currentSelector)
          var tarMods = window.phoenixModels.filter((v, i) => {
            return v.moduleName == dt.link && v.tableSelector == window.currentSelector
          })

          tarMods.forEach((tarMod, i) => {

            try {
              window.prev_page = tarMod.table.page()
              tarMod.reload();
            } catch (e) {
              console.log("cant find the table")

            }
          })

        }

      }).fail(function(e) {
        console.log(e.responseJSON.status);


        phxApp_.notify("Not Added! reason: " + e.responseJSON.status, {
          type: "warning"
        });


      });
    };
    var center = document.createElement("center");
    center.append(confirm_button);
    $("#myModal").find(".modal-body").html(center);
    $("#myModal").modal('show');
  }





}