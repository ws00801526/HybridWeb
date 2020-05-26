// HTTP methods whose capitalization should be normalized
const CRLF = "\r\n"
const methods = ['DELETE', 'GET', 'HEAD', 'OPTIONS', 'POST', 'PUT']

function _normalizeMethod(method) {
  var upcased = method.toUpperCase()
  return methods.indexOf(upcased) > -1 ? upcased : method
}

function _buildPart(key, value) {

  return new Promise((resolve, reject) => {
    var part;
    if (typeof value === "string") {
      return resolve({ 'field': key, 'type': 'text/plain; charset=utf-8', 'value' : unescape(encodeURIComponent(value)) })
    } else if (File.prototype.isPrototypeOf(value)) {
      return _readFile(key, value).then(res => resolve(res))
    } else if (HTMLInputElement.prototype.isPrototypeOf(value)) {
      if (value.type == 'file') {
        // Unsupported
        return reject('Unsupported')
      } else {
         return resolve({ 'field': key, 'type': 'text/plain; charset=utf-8', 'value' : unescape(encodeURIComponent(value)) })
      }
    }
  });
}

function _readFile(key, file) {

  return new Promise((resolve, reject) => {
    const reader = new FileReader()
    if (reader.readyState === FileReader.DONE) {
      return resolve({ 'field': key, 'type': file.type, 'value' : reader.result, 'base64' : true })
    } else {
      reader.onloadend = (event) => {
        const result = event.target.result;
        return resolve({ 'field': key, 'type': file.type, 'value' : reader.result, 'base64' : true })
      }
      reader.readAsDataURL(file)
    }
  });
}

function Request(url, options = {}) {
  this.url = url
  this.method = _normalizeMethod(options.method || 'GET')
  this.forms = options.forms || {}
  this.headers = options.headers || {}
  this.paramters = options.paramters || {}
}

Request.prototype.buildUrl = function() {
  return new Promise((resolve, reject) => {
    if (isEmpty(this.url)) return reject(new Response(new Blob(), {
      status: 400,
      statusText: 'Url is empty'
    }));
    else resolve(this);
  });
}

Request.prototype.buildForm = function() {
    var parts = [];
    const forms = this.forms
    if (FormData.prototype.isPrototypeOf(forms)) {
        for (key of forms.keys()) {
          const value = forms.get(key);
          const part = value && _buildPart(key, value);
          part && parts.push(part);
        }
        return Promise.all(parts).then(forms => { this.forms = forms; return this; })
    } else {
        return new Promise((resolve, reject) => { return resolve(this) })
    }
}

Request.prototype.build = function() {
  return this.buildUrl().then(req => {
    return req.buildForm()
  })
}

Request.prototype.fetch = function(options = {}) {

  const params = {
    ...options,
    url: this.url,
    headers: this.headers,
    method: this.method,
    paramters: this.paramters,
    forms: this.forms
  }
  return new Promise((resolve, reject) => {
    if (window.HBJSBridge) {
      window.HBJSBridge.call('fetch', params, function(res) {
        // res should have status\statusText\body\headers
        // res.body should always be string if it's exists
        console.log(res);
        const status = (res && res.status) || 400
        const statusText = (res && res.statusText) || (res && res.message) || 'Unknown Error';
        const init = {
          status: status,
          statusText: statusText
        }
        if (status >= 200 && status < 300) {
          console.log(res.headers)
          const type = res && res.headers && res.headers['Content-Type']
          const blob = (type && new Blob([res.body], {
            type: type
          })) || new Blob([res.body]);
          resolve(new Response(blob, init));
        } else {
          reject(new Response(new Blob(), init));
        }
      });
    } else {
      reject(new Response(new Blob(), {
        status: 400,
        statusText: 'Bridge is unsupported'
      }));
    }
  })
}

function _fetch(url, options = {}) {
  console.log(`fetch :${url}`)
  console.log(`fetch options :${JSON.stringify(options)}`)
  return new Request(url, options)
    .build()
    .then(req => {
      return req.fetch()
    })
}

function _cancel() {

}

function isEmpty(url) {
  const str = url || ''
  if (str.match(/^\s+$/)) {
    return true;
  }
  if (str.match(/^[ ]+$/)) {
    return true;
  }
  if (str.match(/^[ ]*$/)) {
    return true;
  }
  if (str.match(/^\s*$/)) {
    return true
  }
  return false
}

if (!self.nfetch) {
  self.nfetch = _fetch
}
