/**
 * Created by iwang on 2017/1/15.
 */
//express使用的是@4版本的。
var express = require('express');
//form表单需要的中间件。
var mutipart = require('connect-multiparty');
var logger = require('morgan')
var path = require('path')

var mutipartMiddeware = mutipart();
var app = express();
//下面会修改临时文件的储存位置，如过没有会默认储存别的地方，这里不在详细描述,这个修改临时文件储存的位置 我在百度里查找了三四个小时才找到这个方法，不得不说nodejs真难学。//所以在这里留下我的学习记录，以备以后翻阅。
app.use(mutipart({
  uploadDir: './temp'
}));
app.use(logger())
app.use(express.json()) // for parsing application/json
app.use(express.urlencoded({ extended: true })) // for parsing application/x-www-form-urlencoded
//设置http服务监听的端口号。
app.set('port', process.env.PORT || 3001);
app.listen(app.get('port'), function() {
  console.log("Express started on http://localhost:" + app.get('port') + '; press Ctrl-C to terminate.');
});
//浏览器访问localhost会输出一个html文件
app.get('/', function(req, res) {
  res.type('application/json')
  res.send({
    'message': '请上传文件'
  })
});

var users = {
  "Jhon": {
    "name": "Jhon",
    "age": 23,
    "avatar": null,
    "gender": "male",
    "logined" : false
  },
  "Marry": {
    "name": "Marry",
    "age": 20,
    "avatar": null,
    "gender": "female",
    "logined" : false
  }
};

app.post('/login', function(req, res) {
  const {
    name,
    password
  } = req.body;
  console.log(req.body)
  console.log('login body :' + name + '-' + password + '-' + req.body);
  var user = users[`${name}`]
  if (user) {
    user.logined = true
    users[`${name}`] = user
    res.json({
      'code': 0,
      'message': `${name} login success`
    });
  } else {
    res.json({
      'error': -100,
      'message': `${name} unexists`
    });
  }
});

app.get('/profile', function(req, res) {
  const user = users[`${req.query.name}`];
  res.type('application/json');
  if (user) {
    if (user.logined) { res.json(user) }
    else { res.json({ 'code' : -200, 'message' : '用户未登录, 请先登录' }) }
  } else {
    res.json({
      'code': -100,
      'message': `${req.query.name} unexists`
    });
  }
});

app.get('/temp/:name', function(req, res) {
  var options = {
    root: path.join(__dirname, 'temp'),
    dotfiles: 'deny',
    headers: {
      'x-timestamp': Date.now(),
      'x-sent': true
    }
  }

  var fileName = req.params.name
  res.sendFile(fileName, options, function (err) {
    if (err) {
      next(err)
    } else {
      console.log('Sent:', fileName)
    }
  })
})

//这里就是接受form表单请求的接口路径，请求方式为post。
app.post('/upload', mutipartMiddeware, function(req, res) {
  //这里打印可以看到接收到文件的信息。
  console.log(`--------------`);
  console.log(req.files);
  console.log(req.body);

  const user = users[`${req.body.name}`]
  if (user) {
    user.avatar = `http://localhost:3001/${req.files.file.path}`
    users[`${req.body.name}`] = user
    res.json({
      'code' : '0',
      'message' : 'upload success',
      'path' : `http://localhost:3001/${req.files.file.path}`
    })
  } else {
    res.json({
      'code': -100,
      'message': `${req.body.name} unexists`
    });
  }
});
