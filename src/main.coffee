
# Electron Require
app        = require 'app'               # 应用控制模块
BrowserWin = require 'browser-window'    # 创建客户端窗口模块
Menu       = require 'menu'
ipc        = require 'ipc'
dialog     = require 'dialog'
shell      = require 'shell'

# 注意
# 崩溃报告模块，设置发送报告到自己的服务器，默认是发到作者设置的服务器
# require('crash-reporter').start()

# App Require
path     = require 'path'
fs       = require 'fs'
crypto   = require 'crypto'
request  = require 'request'
chokidar = require 'chokidar'
CSON     = require 'cson'
mime     = require 'mime'
bSync    = require('browser-sync').create()

# Base Set
CWD           = __dirname
APP_VER       = app.getVersion()
SYS_DATA_DIR  = app.getPath('appData')
YHSD_DIR      = SYS_DATA_DIR + '/yhsd'
DATA_DIR      = YHSD_DIR + '/' + app.getName()
HASH_DIR      = './hash'
CONF_PATH     = './conf.cson'
DATA_PATH     = './auto_data.cson'
UI_URI        = 'file://' + path.join CWD, 'index.html'
# UI_URI        = 'http://localhost:8181/index.html'
API_URI       = 'https://api.youhaosuda.com/v1'
TOKEN_URI     = 'https://apps.youhaosuda.com/oauth2/token'
IGNORE_SUFFIX = 'DS_Store'    # 用 | 分隔文件后缀，例如："one|two|three"
IGNORE_DIR    = '.svn'        # 用 | 分隔文件夹名称，例如："one|two|three"
SERVICES_PORT = 8186


# Require 相关设置

## Request 设置
requestOpt =
  pool:
    maxSockets: 1
    keepAlive: true
request    = request.defaults requestOpt
requestJar = do request.jar


# Main 全局变量
conf     = null    # 基本设置
_mainWin = null


# Menu Template
menuTpl = [
  label: 'Theme Dev Tools'
  submenu: [
      label: 'About Theme Dev Tools'
      selector: 'orderFrontStandardAboutPanel:'
    ,
      type: 'separator'
    ,
      label: 'Services'
      submenu: []
    ,
      type: 'separator'
    ,
      label: 'Hide Theme Dev Tools'
      accelerator: 'Command+H'
      selector: 'hide:'
    ,
      label: 'Hide Others'
      accelerator: 'Command+Shift+H'
      selector: 'hideOtherApplications:'
    ,
      label: 'Show All'
      selector: 'unhideAllApplications:'
    ,
      type: 'separator'
    ,
      label: 'Quit'
      accelerator: 'Command+Q'
      selector: 'terminate:'
  ]
  ,
    label: 'Edit'
    submenu: [
      label: 'Undo'
      accelerator: 'Command+Z'
      selector: 'undo:'
    ,
      label: 'Redo'
      accelerator: 'Shift+Command+Z'
      selector: 'redo:'
    ,
      type: 'separator'
    ,
      label: 'Cut'
      accelerator: 'Command+X'
      selector: 'cut:'
    ,
      label: 'Copy'
      accelerator: 'Command+C'
      selector: 'copy:'
    ,
      label: 'Paste'
      accelerator: 'Command+V'
      selector: 'paste:'
    ,
      label: 'Select All'
      accelerator: 'Command+A'
      selector: 'selectAll:'
    ]
  ,
    label: 'View'
    submenu: [
      label: 'Reload'
      accelerator: 'Command+R'
      click: -> _mainWin.reload()
    ,
      label: 'Toggle DevTools'
      accelerator: 'Alt+Command+I'
      click: -> _mainWin.toggleDevTools()
    ]
  ,
    label: 'Window'
    submenu: [
      label: 'Minimize'
      accelerator: 'Command+M'
      selector: 'performMiniaturize:'
    ,
      label: 'Close'
      accelerator: 'Command+W'
      selector: 'performMiniaturize:'
      # selector: 'performClose:'    # 关闭应用
    ,
      type: 'separator'
    ,
      label: 'Bring All to Front'
      selector: 'arrangeInFront:'
    ]
  ,
    label: 'Help'
    submenu: []
]

# Main Debug
_mLog = (msg) ->
  if typeof msg != 'string'
    msg = JSON.stringify msg
  dialog.showMessageBox(_mainWin, {type: 'info', buttons: ['OK'], message: msg})

## 路径处理
pathHandle = (arg) ->
  path.normalize path.resolve(DATA_DIR, arg)

# API
run =
  init: (callback) ->
    # 判断系统数据文件夹
    if !(fs.existsSync(pathHandle SYS_DATA_DIR))
      return callback 'Error - SYS_DATA_DIR 文件夹不存在，软件初始化失败'

    # 判断 YHSD 文件夹
    if !(fs.existsSync pathHandle(YHSD_DIR))
      try
        fs.mkdirSync pathHandle(YHSD_DIR)
      catch e
        return callback 'Error - 创建 YHSD_DIR 文件夹失败 - Error Msg: ' + e

    # 判断数据文件夹
    if !(fs.existsSync(pathHandle DATA_DIR))
      try
        fs.mkdirSync pathHandle(DATA_DIR)
      catch e
        return callback 'Error - 创建 DATA_DIR 文件夹失败 - Error Msg: ' + e

    # 写入 PID 到文件
    if fs.existsSync(pathHandle DATA_DIR)
      try
        fs.writeFileSync pathHandle(DATA_DIR + '/app.pid'), process.pid
      catch e
        return callback 'Error - 创建 App PID 文件失败 - Error Msg: ' + e
    else
      return callback 'Error - DATA_DIR 文件夹不存在 - Error Msg: ' + e

    # 加载基本设置
    if !(fs.existsSync pathHandle(CONF_PATH))
      try
        if !(fs.existsSync pathHandle(DATA_DIR))
          fs.mkdirSync pathHandle(DATA_DIR)
        newConf = new Object
          ver: APP_VER
          dataDir: pathHandle DATA_DIR
        fs.writeFileSync pathHandle(CONF_PATH), CSON.stringify newConf
        conf = newConf
      catch e
        return callback 'Error - 创建基本设置文件失败 - Error Msg: ' + e
    else
      conf = CSON.load pathHandle(CONF_PATH)

    # 判断数据文件
    if !(fs.existsSync pathHandle(DATA_PATH))
     try
        if !(fs.existsSync pathHandle(DATA_DIR))
          fs.mkdirSync pathHandle(DATA_DIR)
        newData = new Object
          ver : APP_VER
          tags:
            all   :
              name  : '全部'
              active: true
            star  :
              name  : '标记'
              active: false
            manage:
              name  : '管理'
              active: false
            dev   :
              name  : '开发'
              active: false
          items : {}
          stores: {}
          tips  : {}
        fs.writeFileSync pathHandle(DATA_PATH), CSON.stringify newData
      catch e
        return callback 'Error - 创建数据文件失败 - Error Msg: ' + e
    callback null
  close: ->
    if fs.existsSync pathHandle(DATA_DIR + '/app.pid')
      try
        fs.unlinkSync pathHandle(DATA_DIR + '/app.pid')
      catch e
        null
    do app.quit
  isRunning: ->
    mark = false
    if fs.existsSync pathHandle(DATA_DIR + '/app.pid')
      pid = fs.readFileSync pathHandle(DATA_DIR + '/app.pid'), 'utf8'
      try
        mark = process.kill pid, 0
      catch e
        null
    mark
  start: ->
    # Mnue Set
    Menu.setApplicationMenu(Menu.buildFromTemplate menuTpl)

    # 创建应用窗口
    _mainWin = new BrowserWin
      width: 400
      height: 710
      fullscreen: false
      resizable: false
      # 'title-bar-style': 'hidden'    # 保留 Mac 红绿灯按钮和可拖动
      frame: false    # 可拖动，需设置 CSS header -webkit-app-region: drag 和 button -webkit-app-region: no-drag

    # 加载界面
    _mainWin.loadUrl UI_URI

    # 启用 DevTools，菜单可以启动
    # _mainWin.openDevTools()

    # 绑定关闭事件
    _mainWin.on 'closed', ->
      _mainWin = null    # 清理环境
      do run.close


    # ------- App -------

    # 变量
    autoData = null    # Auto App 数据
    current  = null    # Auto 活动 Item

    # 方程
    ## 日志显示
    logs = (type, msg) ->
      _mainWin.webContents.send 'logs',
        type: type
        msg : msg

    ## Tips 提示
    tips = (type, msg) ->
      date = (new Date()).getTime()
      obj  =
        date: date
        type: type
        msg : msg
      autoData.add_tip obj, (err) ->
        if err
          logs 'Error', '添加 Tip 出错'
        else
          autoData.setRemote()

    ## Secret 处理
    ## Key = Domain
    secureStorage =
      get: (key, callback) ->
        _mainWin.webContents.session.cookies.get
          url : 'https://theme-dev-tools.app.youhaosuda.com'
          , (err, cookies) ->
            if err
              callback err
            else
              result = null
              for ck in cookies
                if ck.name == key
                  result = ck
                  break
              if !result
                callback '获取 Cookie 数据为空'
                return
              if !result.value
                callback '获取 Cookie 数据为空'
                return
              callback null, JSON.parse(result.value)
      set: (key, obj, callback) ->
        obj['ver'] = APP_VER
        _mainWin.webContents.session.cookies.set
          url   : 'https://theme-dev-tools.app.youhaosuda.com'
          name  : key
          value : JSON.stringify obj
          expirationDate: 31104000000
        , (err) ->
          if err
            callback err
          else
            callback null

    # 对象
    # AutoData 对象
    autoData =
      cont: null
      init: (callback) ->
        self = this
        CSON.load pathHandle(DATA_PATH), (err, data) ->
          return callback err if err
          self.cont = data
          if data.mode
            if data.mode.local?.open
              API_URI   = data.mode.local.api_uri
              TOKEN_URI = data.mode.local.token_uri
          callback null
      save: (callback) ->
        self = this
        try
          if !(fs.existsSync pathHandle(DATA_DIR))
            fs.mkdirSync conf.dataDir
            logs 'Success', '创建 AutoData 文件夹成功'
          fs.writeFileSync pathHandle(DATA_PATH), CSON.stringify(self.cont)
          callback null
        catch e
          callback e
      add_store: (data, callback) ->
        self = this
        rqs.getToken data.app_key, data.app_secret, (err, token) ->
          if !err
            logs 'Info', 'Token - ' + token
            rqs.setToken token
            rqs.get '/shop', (err, shopData) ->
              if !err
                secureStorage.set shopData.shop.domain,
                  app_key   : data.app_key
                  app_secret: data.app_secret
                  token     : token
                , (err) ->
                  if !err
                    self.cont['stores'][shopData.shop.domain] =
                      domain: shopData.shop.domain
                      name: shopData.shop.name
                    self.save (err) ->
                      return callback err if err
                      callback null
                  else
                    callback err
              else
                callback err
          else
            callback err
      up_store: (data, callback) ->
        self = this
        rqs.getToken data.app_key, data.app_secret, (err, token) ->
          if !err
            rqs.setToken token
            rqs.get '/shop', (err, shopData) ->
              if !err
                handle = ->
                  secureStorage.set shopData.shop.domain,
                    app_key   : data.app_key
                    app_secret: data.app_secret
                    token     : token
                  , (err) ->
                    if !err
                      self.cont['stores'][shopData.shop.domain] =
                        domain: shopData.shop.domain
                        name: shopData.shop.name
                      self.save (err) ->
                        return callback err if err
                        callback null
                    else
                      callback err
                if data.domain == shopData.shop.domain
                  handle()
                else
                  self.del_store data.domain, (err) ->
                    logs 'Error', err if err
                    delete self.cont['stores'][data.domain]
                    handle()
              else
                callback err
          else
            callback err
      del_store: (domain, callback) ->
        self = this
        delete self.cont['stores'][domain]
        secureStorage.set domain, {}, (err) ->
          return callback err if err
          self.save (err) ->
            return callback err if err
            callback null
      set_item: (dir, data, callback) ->
        self = this
        self.cont.items[dir].conf =
          store: data.store
          theme: data.theme
        self.save (err) ->
          return callback err if err
          callback null
      add_item: (dir, callback) ->
        self = this
        if !self.cont.items[dir]
          tag = 'all'
          for k, v of self.cont.tags
            if v.active
              tag = k
          self.cont.items[dir] =
            name    : path.basename dir.replace(/[\/\\]+dist$/, '')
            add_time: (new Date()).getTime()
            path    : dir
            tag     : tag
            conf    :
              store: null
              theme: null
          self.save (err) ->
            return callback err if err
            callback null
        else
          callback '文件夹已经存在'
      del_item: (dir, callback) ->
        self = this
        delete self.cont.items[dir]
        self.save (err) ->
          return callback err if err
          callback null
      add_tip: (obj, callback) ->
        self = this
        self.cont.tips[obj.date] = obj
        self.save (err) ->
          return callback err if err
          callback null
      del_tip: (key, callback) ->
        self = this
        delete self.cont.tips[key]
        self.save (err) ->
          return callback err if err
          callback null
      set_tag_active: (key, callback) ->
        self = this
        for k, v of self.cont.tags
          if k == key
            self.cont.tags[k].active = true
          else
            self.cont.tags[k].active = false
        self.save (err) ->
          return callback err if err
          callback null
      setRemote: ->
        self = this
        obj = {}
        obj['autoData'] = self.cont
        obj['current']  = current.cont
        obj['env']      =
          APP_VER      : APP_VER
          DATA_DIR     : pathHandle DATA_DIR
          HASH_DIR     : pathHandle HASH_DIR
          CONF_PATH    : pathHandle CONF_PATH
          DATA_PATH    : pathHandle DATA_PATH
          API_URI      : API_URI
          SERVICES_PORT: SERVICES_PORT
        _mainWin.webContents.send 'set_ui_data', obj
        obj = null

    # Auto Main
    # Data
    current =
      cont: null
      init: (data, callback) ->
        self = this
        self.cont = new Object
          upHash  : {}
          queue   : []
          nowQueue: {}
          isBak   : true
          canRun  : false
          leaky   : '0/40'
          themeDir: data.themeDir
          storeURI: data.storeURI
          themeID : data.themeID
        callback(null)
      clean: ->
        self = this
        self.cont = null

    # Var and Settings
    watcher =
      watch: null
      run: ->
        self = this
        self.watch = chokidar.watch current.cont.themeDir, { ignored: /[\/\\]\./, persistent: true, ignoreInitial: true }
      close: ->
        self = this
        if self.watch
          self.watch.close()

    # Services
    bs =
      reload: null
      run: (callback) ->
        self = this
        if !bSync.active
          bSync.init
            proxy: current.cont.storeURI
            port : SERVICES_PORT
            open : false
            injectChanges: false
            ghostMode: false
            ui: false
          self.reload = bSync.reload
        callback null
      exit: ->
        self = this
        if bSync.active
          # bSync.exit()    # 会退出进程
          bSync.cleanup()
          self.reload = null

    # API LeakyBucket
    bucket =
      throttle: (callback) ->
        if current.cont && current.cont.leaky
          if eval(current.cont.leaky) < 1
            return callback null
          else
            return callback '请求水桶满了，请稍等...'

    # Funtion
    checkSum = (path) ->
      crypto.createHash('md5').update(fs.readFileSync(path), 'utf8').digest 'hex'

    winPathRE = (path) ->
      path.replace(/[\\]/g, '\\\\')

    disPath = (path) ->
      path.replace(new RegExp(winPathRE(current.cont.themeDir) + '[\\/\\\\]'), '')

    # Method
    rqs =
      login: (callback) ->
        self = this
        secureStorage.get current.cont.storeURI, (err, data) ->
          if err
            callback err
          else
            self.setToken data.token
            callback null
      setToken: (token) ->
        requestOpt['headers'] =
          'X-API-ACCESS-TOKEN': token
        request = request.defaults requestOpt
      getToken: (app_key, app_secret, callback) ->
        self = this
        encoded = new Buffer(app_key + ':' + app_secret).toString('base64')
        logs 'Success', 'Get_Token_Start'
        logs 'Info', 'Basic ' + encoded
        request.post
          url: TOKEN_URI
          form:
            grant_type: 'client_credentials'
          headers:
            Authorization: 'Basic ' + encoded
          , (err, response, body) ->
            logs 'Success', 'Get_Token_End'
            if typeof body == 'string'
              oBody = JSON.parse body
            else
              oBody = body
            if !err && response.statusCode == 200
              callback null, oBody.token
            else
              msg = '获取 Token 失败 | HTTP_CODE: ' + response?.statusCode + ' | HTTP_MSG: ' + oBody?.error
              if err
                msg = msg + ' | Request_ERROR: ' + err
              callback msg
      get: (api, callback) ->
        request.get
          uri: API_URI + api
          , (err, response, body) ->
            if typeof body == 'string'
              oBody = JSON.parse body
            else
              oBody = body
            if !err && response.statusCode == 200
              if leaky = response?.headers?['x-yhsd-shop-api-call-limit']
                if current.cont && current.cont.leaky
                  current.cont.leaky = leaky
              return callback null, oBody
            else
              if leaky = response?.headers?['x-yhsd-shop-api-call-limit']
                if current.cont && current.cont.leaky
                  current.cont.leaky = leaky
              msg = 'GET - 获取数据失败 | HTTP_CODE: ' + response?.statusCode + ' | API_MSG: ' + JSON.stringify oBody
              if err
                msg = msg + ' | Request_ERROR: ' + err
              return callback msg
      post: (api, body, callback) ->
        request.post
          uri : API_URI + api
          json: true
          body: body
          , (err, response, body) ->
            if typeof body == 'string'
              oBody = JSON.parse body
            else
              oBody = body
            if !err && response.statusCode == 200
              if leaky = response?.headers?['x-yhsd-shop-api-call-limit']
                if current.cont && current.cont.leaky
                  current.cont.leaky = leaky
              return callback null, oBody
            else
              if leaky = response?.headers?['x-yhsd-shop-api-call-limit']
                if current.cont && current.cont.leaky
                  current.cont.leaky = leaky
              msg = 'POST - 提交数据失败 | HTTP_CODE: ' + response?.statusCode + ' | API_MSG: ' + JSON.stringify oBody
              if err
                msg = msg + ' | Request_ERROR: ' + err
              return callback msg
      put: (api, body, callback) ->
        request.put
          uri : API_URI + api
          json: true
          body: body
          , (err, response, body) ->
            if typeof body == 'string'
              oBody = JSON.parse body
            else
              oBody = body
            if !err && response.statusCode == 200
              if leaky = response?.headers?['x-yhsd-shop-api-call-limit']
                if current.cont && current.cont.leaky
                  current.cont.leaky = leaky
              return callback null, oBody
            else
              if leaky = response?.headers?['x-yhsd-shop-api-call-limit']
                if current.cont && current.cont.leaky
                  current.cont.leaky = leaky
              msg = 'PUT - 更新数据失败 | HTTP_CODE: ' + response?.statusCode + ' | API_MSG: ' + JSON.stringify oBody
              if err
                msg = msg + ' | Request_ERROR: ' + err
              return callback msg
      del: (api, callback) ->
        request.del
          uri: API_URI + api
          , (err, response, body) ->
            if typeof body == 'string'
              oBody = JSON.parse body
            else
              oBody = body
            if !err && response.statusCode == 200
              if leaky = response?.headers?['x-yhsd-shop-api-call-limit']
                if current.cont && current.cont.leaky
                  current.cont.leaky = leaky
              return callback null, oBody
            else
              if leaky = response?.headers?['x-yhsd-shop-api-call-limit']
                if current.cont && current.cont.leaky
                  current.cont.leaky = leaky
              msg = 'DELETE - 删除数据失败 | HTTP_CODE: ' + response?.statusCode + ' | API_MSG: ' + JSON.stringify oBody
              if err
                msg = msg + ' | Request_ERROR: ' + err
              return callback msg
      getFile: (uri, callback) ->
        request.get
          encoding: null        # binary 数据
          url: 'http:' + uri    # 不加上会提示 URI 错误
          , (err, response, body) ->
            if typeof body == 'string'
              oBody = JSON.parse body
            else
              oBody = body
            if !err && response.statusCode == 200
              return callback null, oBody
            else
              msg = 'GET - 获取文件失败 | HTTP_CODE: ' + response?.statusCode + ' | API_MSG: ' + JSON.stringify oBody
              if err
                msg = msg + ' | Request_ERROR: ' + err
              return callback msg
      add: (filePath, callback) ->
        # Name 包含目录名（除结构目录名），例如 system/500.html
        # dirNm 只是结构目录名
        self  = this
        name  = filePath.replace(new RegExp(winPathRE(current.cont.themeDir) + '[\\/\\\\]'), '').replace(/^[^\/\\]+[\/\\]/, '')
        dirNm = filePath.replace(new RegExp(winPathRE(current.cont.themeDir) + '[\\/\\\\]'), '').match(/^[^\/\\]+/)?[0]
        try
          if fs.existsSync(filePath)
            fileHash = checkSum filePath
          else
            err = '添加文件不存在' + ' | FILE_PATH: ' + disPath filePath + ' | ' + e
            return callback err
        catch e
          err = '计算文件 MD5 失败' + ' | FILE_PATH: ' + disPath filePath + ' | ' + e
          return callback(err)
        if (/assets/.test dirNm)
          imgRE = new RegExp('.(png|jpg|gif|jpeg|bmp|webp)$')
          binRE = new RegExp('.(svg|ico|eot|woff|ttf|woff2)$')
          api  = '/themes/' + current.cont.themeID + '/assets'
          # Add 无需删除图片文件后缀名
          body =
            asset:
              key: 'assets/' + path.basename filePath
              value: ''
          if (imgRE.test(filePath) || binRE.test(filePath))
            mimeType = mime.lookup filePath
            body.asset.value = 'data:' + mimeType + ';base64,' + fs.readFileSync(filePath, 'base64')
          else
            body.asset.value = fs.readFileSync(filePath, 'utf8')
          self.post api, body, (err, _body) ->
            if err
              err = err + ' | FILE_PATH: ' + disPath filePath
              return callback err
            else
              current.cont.upHash[filePath] =
                id     : _body.asset.key
                hash   : fileHash
                custom : _body.asset.type == 'custom'
                trash  : _body.asset.trash
                rename : _body.asset.rename
                version: _body.asset.version
              logs 'Success', '线上添加文件成功'
              bs.reload filePath
              return callback null
        else
          fileType = path.extname filePath
          if fileType != '.html' && fileType != '.json'
            err = '添加的文件类型不符合要求' + ' - ' + disPath filePath
            return callback err
          else
            # if (/config/.test dirNm)
            #   err = 'Config 目录不允许添加文件' + ' - ' + disPath filePath
            #   return callback err
            api  = '/themes/' + current.cont.themeID + '/assets'
            body =
              asset:
                key: dirNm + '/' + name.replace('\\', '/')
                value: fs.readFileSync(filePath, 'utf8')
            self.post api, body, (err, _body) ->
              if err
                err = err + ' | File: ' + disPath filePath
                return callback err
              else
                logs 'Success', '添加线上文件成功'
                current.cont.upHash[filePath] =
                  id     : _body.asset.key
                  hash   : fileHash
                  custom : _body.asset.type == 'custom'
                  trash  : _body.asset.trash
                  rename : _body.asset.rename
                  version: _body.asset.version
                bs.reload filePath
                return callback null
      update: (filePath, callback) ->
        self = this
        try
          fileHash = checkSum filePath
        catch e
          err = '计算文件 MD5 失败，文件或许不存在' + ' | FILE_PATH: ' + disPath filePath + ' | ' + e
          return callback err

        data = current.cont.upHash[filePath]

        return callback null if data.hash == fileHash

        # 非自定义文件，跳转到添加文件任务
        if !data.custom
          return self.add filePath, (err) ->
            return callback err if err
            return callback null
        else
          # Name 包含目录名（除结构目录名），例如 system/500.html
          # dirNm 只是结构目录名
          name     = filePath.replace(new RegExp(winPathRE(current.cont.themeDir) + '[\\/\\\\]'), '').replace(/^[^\/\\]+[\/\\]/, '')
          dirNm    = filePath.replace(new RegExp(winPathRE(current.cont.themeDir) + '[\\/\\\\]'), '').match(/^[^\/\\]+/)?[0]
          fileType = path.extname filePath
          imgRE    = new RegExp('.(png|jpg|gif|jpeg|bmp|webp)$')
          binRE    = new RegExp('.(svg|ico|eot|woff|ttf|woff2)$')

          if (/assets/.test dirNm)
            # Update 要删除图片文件后缀名
            keyName = name
            if imgRE.test keyName
              keyName = keyName.replace imgRE, ''

            api  = '/themes/' + current.cont.themeID + '/assets'
            body =
              asset:
                key    : 'assets/' + keyName.replace('\\', '/')
                value  : ''
                version: current.cont.upHash[filePath].version

            if (imgRE.test(filePath) || binRE.test(filePath))
              mimeType = mime.lookup filePath
              body.asset.value = 'data:' + mimeType + ';base64,' + fs.readFileSync(filePath, 'base64')
            else
              body.asset.value = fs.readFileSync(filePath, 'utf8')
            self.put api, body, (err, _body) ->
              if err
                err = err + ' | FILE_PATH: ' + disPath filePath
                return callback err
              else
                current.cont.upHash[filePath].hash    = fileHash
                current.cont.upHash[filePath].custom  = _body.asset.type == 'custom'
                current.cont.upHash[filePath].trash   = _body.asset.trash
                current.cont.upHash[filePath].rename  = _body.asset.rename
                current.cont.upHash[filePath].version = _body.asset.version

                logs 'Success', '更新线上文件成功'
                bs.reload filePath
                return callback null
          else
            if fileType != '.html' && fileType != '.json'
              err = '更新的文件类型不符合要求' + ' | FILE_PATH: ' + disPath filePath
              return callback err
            else
              api  = '/themes/' + current.cont.themeID + '/assets'
              body =
                asset:
                  key    : dirNm + '/' + name.replace('\\', '/')
                  value  : fs.readFileSync(filePath, 'utf8')
                  version: current.cont.upHash[filePath].version

              self.put api, body, (err, _body) ->
                if err
                  err = err + ' | FILE_PATH: ' + disPath filePath
                  return callback err
                else
                  current.cont.upHash[filePath].hash    = fileHash
                  current.cont.upHash[filePath].custom  = _body.asset.type == 'custom'
                  current.cont.upHash[filePath].trash   = _body.asset.trash
                  current.cont.upHash[filePath].rename  = _body.asset.rename
                  current.cont.upHash[filePath].version = _body.asset.version

                  logs 'Success', '更新线上文件成功'
                  bs.reload filePath
                  return callback(null)
      remove: (filePath, callback) ->
        self = this

        data = current.cont.upHash[filePath]

        if !data.trash
          logs 'Warning', '文件不允许删除，将重新下载'
          self.down filePath, (err) ->
            return callback err if err
            return callback null
        else
          # Name 包含目录名（除结构目录名），例如 system/500.html
          # dirNm 只是结构目录名
          name  = filePath.replace(new RegExp(winPathRE(current.cont.themeDir) + '[\\/\\\\]'), '').replace(/^[^\/\\]+[\/\\]/, '')
          dirNm = filePath.replace(new RegExp(winPathRE(current.cont.themeDir) + '[\\/\\\\]'), '').match(/^[^\/\\]+/)?[0]
          api   = '/themes/' + current.cont.themeID + '/assets?asset[key]=' + dirNm + '/' + name.replace('\\', '/')
          imgRE = new RegExp('.(png|jpg|gif|jpeg|bmp|webp)$')

          # 去除图片文件扩展名
          if (/assets/.test dirNm)
            if imgRE.test(filePath)
              api = api.replace imgRE, ''

          self.del api, (err) ->
            if err
              err = err + ' | FILE_PATH: ' + disPath filePath
              return callback err
            else
              delete current.cont.upHash[filePath]
              logs 'Success', '删除线上文件成功'
              bs.reload filePath
              return callback(null)
      down: (filePath, callback) ->
        # Name 包含目录名（除结构目录名），例如 system/500.html
        # dirNm 只是结构目录名
        self  = this
        name  = filePath.replace(new RegExp(winPathRE(current.cont.themeDir) + '[\\/\\\\]'), '').replace(/^[^\/\\]+[\/\\]/, '')
        dirNm = filePath.replace(new RegExp(winPathRE(current.cont.themeDir) + '[\\/\\\\]'), '').match(/^[^\/\\]+/)?[0]
        imgRE = new RegExp('.(png|jpg|gif|jpeg|bmp|webp)$')
        binRE = new RegExp('.(svg|ico|eot|woff|ttf|woff2)$')

        # 删除图片文件后缀名
        keyName = name
        if imgRE.test keyName
          keyName = keyName.replace imgRE, ''

        api = '/themes/' + current.cont.themeID + '/assets?asset[key]=' + dirNm + '/' + keyName.replace('\\', '/')

        self.get api, (err, body) ->
          if err
            return callback err
          else
            downHandle = ->
              fileHash = ''
              try
                fileHash = checkSum filePath
              catch e
                err = '计算下载文件 MD5 失败' + ' - ' + disPath filePath + ' | ' + e
                logs 'Warning', err

              current.cont.upHash[filePath].hash    = fileHash
              current.cont.upHash[filePath].custom  = body.asset.type == 'custom'
              current.cont.upHash[filePath].trash   = body.asset.trash
              current.cont.upHash[filePath].rename  = body.asset.rename
              current.cont.upHash[filePath].version = body.asset.version

              logs 'Success', '下载文件成功' + ' - ' + disPath filePath
              return callback null

            # 下载处理
            try
              # 创建目录
              if !fs.existsSync(path.dirname filePath)
                mkdirs_Sync = (dirPath) ->
                  dirPath = path.resolve dirPath
                  if !fs.existsSync(dirPath)
                    try
                      fs.mkdirSync dirPath
                    catch e
                      switch e.code
                        when 'ENOENT'
                          mkdirs_Sync path.dirname(dirPath)
                          mkdirs_Sync dirPath
                        when 'EEXIST'
                          break
                        else
                          throw e
                try
                  mkdirs_Sync(path.dirname filePath)
                  logs 'Success', '创建文件夹成功 - ' + disPath(path.dirname filePath)
                catch e
                  err = '下载文件失败，文件夹创建出错 | ' + e
                  logs 'Warning', err
                  return callback err

              # 创建文件
              if (/assets/.test dirNm)
                if (imgRE.test(filePath) || binRE.test(filePath))
                  # 下载程序
                  if body.asset.public_url
                    self.getFile body.asset.public_url, (err, binBody) ->
                      if err
                        return callback err
                      else
                        # 有空最好判断下文件类型
                        # 重置图片后缀，防止重复名称的图片
                        filePath = filePath.replace(path.basename(filePath), '') + body.asset.name
                        fs.writeFileSync filePath, binBody, 'binary'
                        do downHandle
                  else
                    err = '下载文件失败，文件 URI 为空 - ' + disPath filePath
                    logs 'Warning', err
                    return callback err
                else
                  fs.writeFileSync filePath, body.asset.value, 'utf8'
                  do downHandle
              else
                fs.writeFileSync filePath, body.asset.value, 'utf8'
                do downHandle
            catch e
              err = '下载文件失败' + ' | ' + e
              logs 'Warning', err
              return callback err
      getFileList: (callback) ->
        self = this
        api  = '/themes/' + current.cont.themeID + '/assets'
        self.get api, (err, body) ->
          if err
            return callback err
          else
            olFiles  = {}
            assetsRE = new RegExp('^assets')
            imgRE    = new RegExp('.(png|jpg|gif|jpeg|bmp|webp)$')
            for item in body.assets
              if typeof item == 'object'
                if assetsRE.test(item.key) && imgRE.test(item.name)
                  item.key = item.key + item.name?.match(/\.[^\.]+$/)[0]
                olFiles[path.resolve(current.cont.themeDir + '/' + item.key)] =
                  id     : item.key
                  hash   : ''
                  custom : item.type == 'custom'
                  trash  : item.trash
                  rename : item.rename
                  version: item.version
                  # updated_at: item.updated_at    # 已有
                  # hash  : ''    # 无需
            return callback(null, olFiles)

      runQueue: (queue, callback) ->
        self = this
        if queue.type == 'add'
          return self.add queue.path, (err) ->
            return callback err if err
            return callback null
        if queue.type == 'update'
          return self.update queue.path, (err) ->
            return callback err if err
            return callback null
        if queue.type == 'down'
          return self.down queue.path, (err) ->
            return callback err if err
            return callback null
        if queue.type == 'remove'
          return self.remove queue.path, (err) ->
            return callback err if err
            return callback null
        return callback '列队处理类型错误' + ' | Type: ' + queue.type + ' | File: ' + disPath queue.path

    file =
      getListHandle: (dir) ->
        walkList     = []
        ignoreSuffix = new RegExp('(' + IGNORE_SUFFIX + ')$')
        ignoreDir    = new RegExp('(' + IGNORE_DIR + ')$')
        walk = (dir) ->
          for item in fs.readdirSync(dir)
            if fs.statSync(path.resolve(dir + '/' + item)).isDirectory()
              if !(ignoreDir.test item)
                walk path.resolve(dir + '/' + item)
            else
              if !(ignoreSuffix.test item)
                walkList.push path.resolve(dir + '/' + item)
          walkList
        return walk(dir)

      getList: (callback) ->
        self = this
        try
          fileList = self.getListHandle current.cont.themeDir
        catch e
          return callback '读取本地文件列表失败' + ' | ' + e
        if !fileList
          return callback '读取的本地文件为空' + ' | ' + e
        else
          return callback null, fileList

      getUpHash: (oOlFiles, callback) ->
        self = this
        self.getList (err, fileList) ->
          return callback err if err
          upHash = current.cont.upHash
          dirRE  = new RegExp(winPathRE(current.cont.themeDir) + '[\\/\\\\][assets|templates|snippets|layout|config]')
          # 处理本地文件
          # ID 用文件绝对路径，不要用 Key 的相对路径，减少用户的不正规操作造成线上主题显示错误，影响营业
          try
            for offlItem in fileList
              if dirRE.test(offlItem)
                fileHash = checkSum offlItem
                upHash[offlItem] =
                  id     : oOlFiles[offlItem]?.id      || ''
                  hash   : fileHash                    || ''
                  custom : oOlFiles[offlItem]?.custom  || false
                  trash  : oOlFiles[offlItem]?.trash   || false
                  rename : oOlFiles[offlItem]?.rename  || false
                  version: oOlFiles[offlItem]?.version || null
          catch e
            return callback '计算文件 Hash 出错' + ' | ' + e
          # 处理线上文件
          for _key, _item of oOlFiles
            unless upHash[_key]
              upHash[_key] =
                id     : oOlFiles[_key]?.id      || ''
                hash   : ''
                custom : oOlFiles[_key]?.custom  || false
                trash  : oOlFiles[_key]?.trash   || false
                rename : oOlFiles[_key]?.rename  || false
                version: oOlFiles[_key]?.version || null
          return callback null, upHash

      getBakHash: (callback) ->
        bakPath = path.resolve(pathHandle(HASH_DIR) + '/' + current.cont.themeID + '.bak')
        try
          if fs.existsSync bakPath
            content = fs.readFileSync(bakPath, 'utf8')
            if content && content != ''
              try
                bakHash = CSON.parse content
              catch e
                return callback '解析 JSON 错误，BakHash 内容格式无效' + ' | ' + e
              if bakHash
                logs 'Success', '读取 BakHash 文件成功'
                return callback null, bakHash
        catch e
          return callback '读取 BakHash 文件出错' + ' | ' + e
        callback  'BakHash 文件不存在或内容为空'

      setBakHash: (callback) ->
        bakPath = path.resolve(pathHandle(HASH_DIR) + '/' + current.cont.themeID + '.bak')
        try
          if !fs.existsSync(pathHandle(HASH_DIR))
            fs.mkdirSync pathHandle(HASH_DIR)
            logs 'Success', '创建 BakHash 文件夹成功'
          fs.writeFileSync bakPath, CSON.stringify(current.cont.upHash)
        catch e
          err = '备份数据失败' + ' | ' + e
          logs 'Warning', err
          return callback err
        logs 'Success', '备份数据成功'
        return callback null
      watch:
        run: (callback) ->
          logs 'Success', 'Watching... ' + current.cont.themeDir
          checkSet = (path, type) ->
            if type == 'add' || type == 'change'
              if data = current.cont.upHash[path]
                try
                  hash = checkSum path
                catch e
                  logs 'Warning', '计算文件 Hash 出错' + ' | ' + e
                  return
                if data.hash != hash
                  logs 'Info', 'Watcher Changed - ' + disPath path
                  auto.queue.add 'update', path
              else
                logs 'Info', 'Watcher Added - ' + disPath path
                auto.queue.add 'add', path
            else
              if type == 'unlink' && current.cont.upHash[path]
                logs 'Info', 'Watcher Removed - ' + disPath path
                auto.queue.add 'remove', path

          watcher.run()
          watcher.watch.on 'add', (path) ->
            checkSet(path, 'add')
          watcher.watch.on 'change', (path) ->
            checkSet(path, 'change')
          watcher.watch.on 'unlink', (path) ->
            checkSet(path, 'unlink')
          callback null
        close: ->
          watcher.close()

    # App API
    auto =
      queue:
        state:
          stop: false
        handle: ->
          self = this
          if self.state.stop
            auto.close (err) ->
              if err
                logs 'Error', err
          else
            bucket.throttle (err) ->
              if err
                logs 'Warning', err
                setTimeout ->
                  current.cont.leaky = '1/40'
                  self.handle()
                , 1000
              else
                current.cont.nowQueue = self.get()
                if current.cont.nowQueue
                  current.cont.isBak = true
                  return rqs.runQueue current.cont.nowQueue, (err) ->
                    logs 'Warning', err if err
                    self.handle()
                else
                  outFn = ->
                    self.handle()
                  if current.cont.isBak
                    return file.setBakHash (err) ->
                      logs 'Info', 'Run...'
                      current.cont.isBak = false if !err
                      setTimeout outFn, 500
                  else
                    return setTimeout outFn, 500
        add: (type, path) ->
          logs 'Info', 'Queue - ' + type + ' - ' + path
          current.cont.queue.push
            type: type,
            path: path
        get: ->
          current.cont.queue.shift()
        length: ->
          current.cont.queue.length
      run: (data, callback) ->
        self = this
        logs 'Info', '主题开发辅助工具已启动...'
        current.init data, (err) ->
          return callback err if err

          rqs.login (err) ->
            return callback err if err
            logs 'Info', '登陆成功'

            rqs.getFileList (err, olFiles) ->
              return callback err if err
              logs 'Info', '获取线上文件列表成功'

              file.getUpHash olFiles, (err, upHash) ->
                return callback err if err
                logs 'Info', '合并文件列表成功'

                file.getBakHash (err, bakHash) ->
                  if err
                    logs 'Warning', err
                    bakHash = {}
                  for name, item of upHash
                    # 有 ID 说明 线上存在该文件
                    if item.id
                      # 有 Hash 说明，线下存在该文件
                      if item.hash
                        # BakHash 文件存在该文件信息才会保留是否自定义状态，否则弹对话框选择是否备份当前文件然后强制更新线上文件
                        # 有空写个强制更新线上文件选择
                        if bakHash[name]
                          # 版本相同，说明线上文件没有修改过
                          if item.version == bakHash[name].version
                            if item.hash == bakHash[name].hash
                              # 文件无需更新
                              continue
                            else
                              # 设置 upHash 里该文件的应该与 bakHash 里该文件的值相同，防止 Update 操作失败时，下次不是进入到这里，因为 Update 操作失败时，不会操作 upHash
                              current.cont.upHash[name].hash    = bakHash[name].hash
                              current.cont.upHash[name].custom  = bakHash[name].custom
                              current.cont.upHash[name].trash   = bakHash[name].trash
                              current.cont.upHash[name].rename  = bakHash[name].rename
                              current.cont.upHash[name].version = bakHash[name].version

                              # 用户自己操作过文件，但不清楚是否是用户真正需要的数据（用旧文件替换了），有时间再写兼容此场景的代码（弹对话框提示选择？）
                              # 暂时默认是更新

                              self.queue.add 'update', name
                          else
                            # Hash 相同，说明线下文件没有修改过

                            # 设置 upHash 里该文件的应该与 bakHash 里该文件的值相同，防止 Update 操作失败时，下次不是进入到这里，因为 Update 操作失败时，不会操作 upHash
                            current.cont.upHash[name].custom  = bakHash[name].custom
                            current.cont.upHash[name].trash   = bakHash[name].trash
                            current.cont.upHash[name].rename  = bakHash[name].rename
                            current.cont.upHash[name].version = bakHash[name].version
                            # 下面判断后才需还原 Hash

                            if item.hash == bakHash[name].hash
                              logs 'Warning', '线上有修改过该文件，请备份并删除该文件，然后重新运行程序，会自动下载该文件最新版本，请在此最新文件上做修改 - ' + disPath name
                            else
                              # 需还原 Hash
                              current.cont.upHash[name].hash = bakHash[name].hash
                              logs 'Warning', '线上和线下都有修改过该文件，请备份并删除该文件，然后重新运行程序，会自动下载该文件最新版本，请在此最新文件上做修改 - ' + disPath name
                        else
                          # 有空在写弹对话框是是否备份当前文件然后强制更新线上文件
                          # 暂时默认是强制更新线上文件

                          # 更新文件前会再次获取文件 Hash 做判断来减少重复更新，也因为 Update 操作失败时，不会操作 hash 为 ''，所以要设置 ''，引导该文件在程序下次启动时会进入 Update 状态
                          current.cont.upHash[name].hash = ''
                          self.queue.add 'update', name
                      else
                        self.queue.add 'down', name
                    else
                      self.queue.add 'add', name
                  file.watch.run (err) ->
                    logs 'Warning', err if err
                    bs.run ->
                      self.queue.handle()
                      callback null
      close: (callback) ->
        self = this
        file.watch.close()
        bs.exit()
        current.clean()
        self.queue.state.stop = false
        requestOpt['headers'] =
          'X-API-ACCESS-TOKEN': ''
        request = request.defaults requestOpt
        logs 'Success', '停止项目运行成功'
        autoData.setRemote()
        _mainWin.webContents.send 'Success', 'stop_item'
        callback null


    # 监听事件
    ipc.on 'quit_app', ->
      auto.close (err) ->
        if !err
          do run.close

    ipc.on 'hide_app', ->
      _mainWin.minimize()

    ipc.on 'open_dir', (evt, path) ->
      if fs.existsSync(pathHandle path)
        shell.openItem path

    ipc.on 'open_uri', (evt, path) ->
      shell.openExternal path

    ipc.on 'get_ui_data', ->
      autoData.setRemote()

    ipc.on 'run_item', (evt, data) ->
      if !current.cont
        auto.run data, (err) ->
          if err
            logs 'Error', err
            auto.close (err) ->
              if !err
                autoData.setRemote()
                _mainWin.webContents.send 'Error', 'run_item'
          else
            autoData.setRemote()
            _mainWin.webContents.send 'Success', 'run_item'
      else
        auto.close (err) ->
          if !err
            autoData.setRemote()
            _mainWin.webContents.send 'Error', 'run_item'

    ipc.on 'stop_item', (evt) ->
      auto.queue.state.stop = true

    ipc.on 'close_item', (evt) ->
      auto.close (err) ->
        if err
          logs 'Error', err
          _mainWin.webContents.send 'Error', 'close_item'
          return
        autoData.setRemote()
        _mainWin.webContents.send 'Success', 'close_item'

    ipc.on 'add_store', (evt, data) ->
      autoData.add_store data, (err) ->
        if err
          logs 'Error', err
          _mainWin.webContents.send 'Error', 'add_store'
          return
        autoData.setRemote()
        _mainWin.webContents.send 'Success', 'add_store'

    ipc.on 'del_store', (evt, domain) ->
      autoData.del_store domain, (err) ->
        if err
          logs 'Error', err
          _mainWin.webContents.send 'Error', 'del_store'
          return
        autoData.setRemote()
        _mainWin.webContents.send 'Success', 'del_store'

    ipc.on 'up_store', (evt, domain) ->
      autoData.up_store domain, (err) ->
        if err
          logs 'Error', err
          _mainWin.webContents.send 'Error', 'up_store'
          return
        autoData.setRemote()
        _mainWin.webContents.send 'Success', 'up_store'

    ipc.on 'set_item', (evt, obj) ->
      autoData.set_item obj.dir, obj.data, (err) ->
        if err
          logs 'Error', err
          _mainWin.webContents.send 'Error', 'set_item'
          return
        autoData.setRemote()
        _mainWin.webContents.send 'Success', 'set_item'

    ipc.on 'add_item', (evt, dir) ->
      autoData.add_item dir, (err) ->
        if err
          logs 'Error', err
          _mainWin.webContents.send 'Error', 'add_item'
          return
        autoData.setRemote()
        _mainWin.webContents.send 'Success', 'add_item'

    ipc.on 'del_item', (evt, dir) ->
      autoData.del_item dir, (err) ->
        if err
          logs 'Error', err
          _mainWin.webContents.send 'Error', 'del_item'
          return
        autoData.setRemote()
        _mainWin.webContents.send 'Success', 'del_item'

    ipc.on 'get_theme', (evt, store) ->
      secureStorage.get store, (err, data) ->
        if err
          logs 'Error', err
          _mainWin.webContents.send 'Error', 'get_theme'
          return
        rqs.setToken data.token
        rqs.get '/themes', (err, data) ->
          if err
            logs 'Error', err
            _mainWin.webContents.send 'Error', 'get_theme'
            return
          result = {}
          for key, theme of data.themes
            result[theme.id] = theme
          _mainWin.webContents.send 'set_theme', result
          rqs.setToken null

    ipc.on 'del_tip', (evt, key) ->
      autoData.del_tip key, (err) ->
        if err
          logs 'Error', err
          _mainWin.webContents.send 'Error', 'del_tip'
          return
        autoData.setRemote()
        _mainWin.webContents.send 'Success', 'del_tip'

    ipc.on 'set_tag_active', (evt, key) ->
      autoData.set_tag_active key, (err) ->
        if err
          logs 'Error', err
          _mainWin.webContents.send 'Error', 'set_tag_active'
          return
        autoData.setRemote()
        _mainWin.webContents.send 'Success', 'set_tag_active'

    # _mainWin 完成加载时，发送事件给 _mainWin
    _mainWin.webContents.on 'did-finish-load', ->

      # 加载 App 数据
      autoData.init (err) ->
        if err
          _mLog err
          logs 'Error', '读取 AutoData 数据失败 Error: ' + err
          return
        logs 'Info', '初始化数据成功'
        _mainWin.webContents.send 'Success', 'init_data'

# 事件
## 绑定关闭所有窗口事件
app.on 'window-all-closed', ->
  if process.platform != 'darwin'
    do run.close

# App Init
app.on 'ready', ->
  # 防止双开
  if run.isRunning()
    do app.quit
  else
    run.init (err) ->
      if err
        _mLog err
        do run.close
      else
        do run.start
