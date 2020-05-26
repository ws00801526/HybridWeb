window.document.addEventListener('HBJSBridgeReady', function() {
    console.log('Bridge is ready in yyyyyy');
})

function lifeCycle() {
    document.addEventListener('pageResume', function(e) {
        console.log('page resumt :' + JSON.stringify(e.detail))
    });
    document.addEventListener('pagePause', function(e) {
        console.log('page pause :' + JSON.stringify(e.detail))
    });
    document.addEventListener('appResume', function(e) {
        console.log('app resume :' + JSON.stringify(e.detail))
    });
    document.addEventListener('appPause', function(e) {
        console.log('app pause :' + JSON.stringify(e.detail))
    });
}


function checkApi() {
    HBJSBridge.call('checkApi', function(res) {
        console.log('checkApi Response :')
        console.log(JSON.stringify(res))
        alert(JSON.stringify(res))
    })
}

function push() {
    var value = document.getElementById('configArea').value;
    var json = JSON.parse(value);
    HBJSBridge.call('push', { 'url' : 'https://www.baidu.com', 'config': json || {} })
}

function pop() {
    HBJSBridge.call('pop', { 'refresh' : true })
}

function pasteboard() {

    HBJSBridge.call('pasteboard', { 'string' : '' }, function (res) {
        console.log('this is res :' + res)
        alert(res)
    })
}

function config() {

    var value = document.getElementById('configArea').value;
    var json = JSON.parse(value);
    HBJSBridge.call('webConfig', json, function(res) {
        console.log('webConfig Response :');
        console.log(res);
        var area = document.getElementById('configArea');
        if (area) { area.value = JSON.stringify(res); }
    })
}

isAutoRead = true;
function autoRead() {
    isAutoRead = !isAutoRead;
    HBJSBridge.call('webConfig', { autoReadTitle : isAutoRead }, function(res) {
        var area = document.getElementById('configArea');
        if (area) { area.value = JSON.stringify(res); }
    })
}

function updateTitle() {
    document.title =  Math.random().toString(36).substring(7);
}



//////// ------- HTTP ------ //////
const url = 'http://localhost:3001'
function http_get() {
    if (window.nfetch) {
        //        appid=68581954&appsecret=pKrb2HOv&version=v9&cityid=0&city=%E4%B8%8A%E6%B5%B7
        // const querys = { 'appid': '68581954', 'appsecret' : 'pKrb2HOv', 'version' : 'v9', 'city' : '上海' }
        // nfetch('https://www.tianqiapi.com/free/day?', { 'querys' : querys })
        // .then(res => { return res.json() })
        // .then(json => alert(JSON.stringify(json)))
        // .catch(res => {
        //    console.error(res);
        //    alert('Get catch error :' + (res &&  res.statusText) || res || 'unknown');
        // })

        nfetch(`${url}/profile`, { 'paramters' : { 'name' : 'Jhon' } })
        .then(res => { return res.json() })
        .then(json => alert(JSON.stringify(json)))
        .catch(res => {
           console.error(res);
           alert('Get catch error :' + (res &&  res.statusText) || res || 'unknown');
        })
    } else {
        alert('HTTP Bridge is unsupported')
    }
}

function http_post() {
    if (window.nfetch) {
        nfetch(`${url}/login`, { 'method' : 'POST', 'paramters' : { 'name' : 'Jhon', 'password' : '123456l' } })
        .then(res => { return res.json() })
        .then(json => alert(JSON.stringify(json)))
        .catch(res => {
           alert('POST catch error :' + (res &&  res.statusText) || res || 'unknown');
           console.log('http post catch error :' + res.statusText)
        })
    } else {
        alert('HTTP Bridge is unsupported')
    }
}

function http_upload() {
    if (window.nfetch) {
        var formData = new FormData();
        var photos = document.querySelector("#upload_file");

        formData.append('type', '17');
        formData.append('fileName', 'dsakldsal');
        formData.append('name', 'Jhon');
        // formData 只接受文件、Blob 或字符串，不能直接传递数组，所以必须循环嵌入
        for (let i = 0; i < photos.files.length; i++) {
            formData.append('file', photos.files[i]);
        }

        nfetch(`${url}/upload`, { 'method' : 'POST', 'forms' : formData })
        .then(res => res.json())
        .then(json => alert(JSON.stringify(json)))
        .catch(res => {
           console.error(res);
           alert('Upload catch error :' + (res &&  res.statusText) || res || 'unknown');
           console.log('http post catch error :' + res.statusText)
        })
    } else {
        alert('HTTP Bridge is unsupported')
    }
}
