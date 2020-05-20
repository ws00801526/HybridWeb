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
