
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
path        = require 'path'
fs          = require 'fs'
crypto      = require 'crypto'
request     = require 'request'
chokidar    = require 'chokidar'
CSON        = require 'cson'
mime        = require 'mime'
bSync       = require('browser-sync').create()

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
          url : 'https://auto.app.youhaosuda.com'
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
          url : 'https://auto.app.youhaosuda.com'
          name : key
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
          API_URI      : pathHandle API_URI
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
            callback null
          else
            callback '水桶满了'

    # Funtion
    checksum = (path) ->
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
              leaky = response.headers['x-yhsd-shop-api-call-limit']
              if leaky
                if current.cont && current.cont.leaky
                  current.cont.leaky = leaky
              callback null, oBody
            else
              msg = 'GET - 获取数据失败 | HTTP_CODE: ' + response?.statusCode + ' | API_MSG: ' + JSON.stringify oBody
              if err
                msg = msg + ' | Request_ERROR: ' + err
              callback msg
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
              leaky = response.headers['x-yhsd-shop-api-call-limit']
              if leaky
                if current.cont && current.cont.leaky
                  current.cont.leaky = leaky
              callback null, oBody
            else
              msg = 'POST - 提交数据失败 | HTTP_CODE: ' + response?.statusCode + ' | API_MSG: ' + JSON.stringify oBody
              if err
                msg = msg + ' | Request_ERROR: ' + err
              callback msg
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
              leaky = response.headers['x-yhsd-shop-api-call-limit']
              if leaky
                if current.cont && current.cont.leaky
                  current.cont.leaky = leaky
              callback null, oBody
            else
              msg = 'PUT - 更新数据失败 | HTTP_CODE: ' + response?.statusCode + ' | API_MSG: ' + JSON.stringify oBody
              if err
                msg = msg + ' | Request_ERROR: ' + err
              callback msg
      add: (filePath, callback) ->
        self  = this
        name  = filePath.replace(new RegExp(winPathRE(current.cont.themeDir) + '[\\/\\\\]'), '').replace(/^[^\/\\]+[\/\\]/, '')
        dirNm = filePath.replace(new RegExp(winPathRE(current.cont.themeDir) + '[\\/\\\\]'), '').match(/^[^\/\\]+/)?[0]
        try
          if fs.existsSync(filePath)
            fileHash = checksum filePath
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
          body =
            asset:
              key: 'assets/' + path.basename filePath
              value: ''
          if (imgRE.test(filePath) || binRE.test(filePath))
            fileType = mime.lookup filePath
            body.asset.value = 'data:' + fileType + ';base64,' + fs.readFileSync(filePath, 'base64')
          else
            body.asset.value = fs.readFileSync(filePath, 'utf8')
          self.post api, body, (err) ->
            if err
              err = err + ' | FILE_PATH: ' + disPath filePath
              return callback err
            else
              current.cont.upHash[filePath]        = {}
              current.cont.upHash[filePath].id     = body.asset.key
              current.cont.upHash[filePath].hash   = fileHash
              current.cont.upHash[filePath].custom = true
              logs 'Success', '线上添加文件成功'
              bs.reload filePath
              return callback null
        else
          fileType = path.extname filePath
          if fileType != '.html' && fileType != '.json'
            err = '添加的文件类型不符合要求' + ' | FILE_PATH: ' + disPath filePath
            return callback err
          else
            api  = '/themes/' + current.cont.themeID + '/assets'
            body =
              asset:
                key: dirNm + '/' + name.replace('\\', '/')
                value: fs.readFileSync(filePath, 'utf8')
            self.post api, body, (err) ->
              if err
                err = err + ' | FILE_PATH: ' + disPath filePath
                return callback err
              else
                current.cont.upHash[filePath]        = {}
                current.cont.upHash[filePath].id     = body.asset.key
                current.cont.upHash[filePath].hash   = fileHash
                current.cont.upHash[filePath].custom = true
                logs 'Success', '添加线上文件成功'
                bs.reload filePath
                return callback(null)
      update: (filePath, callback) ->
        self = this
        try
          fileHash = checksum filePath
        catch e
          err = '计算文件 MD5 失败，文件或许不存在' + ' | FILE_PATH: ' + disPath fileHash + ' | ' + e
          return callback err

        data = current.cont.upHash[filePath]

        return callback null if data.hash == fileHash

        if !data.custom
          self.add filePath, (err) ->
            return callback err if err
            return callback null
        else
          name     = filePath.replace(new RegExp(winPathRE(current.cont.themeDir) + '[\\/\\\\]'), '').replace(/^[^\/\\]+[\/\\]/, '')
          dirNm    = filePath.replace(new RegExp(winPathRE(current.cont.themeDir) + '[\\/\\\\]'), '').match(/^[^\/\\]+/)?[0]
          fileType = path.extname filePath
          imgRE    = new RegExp('.(png|jpg|gif|jpeg|bmp|webp)$')
          binRE    = new RegExp('.(svg|ico|eot|woff|ttf|woff2)$')

          if (/assets/.test dirNm)
            if imgRE.test name
              name = name.replace imgRE, ''

            api  = '/themes/' + current.cont.themeID + '/assets'
            body =
              asset:
                key: 'assets/' + name.replace('\\', '/')
                value: ''
            if (imgRE.test(filePath) || binRE.test(filePath))
              fileType = mime.lookup filePath
              body.asset.value = 'data:' + fileType + ';base64,' + fs.readFileSync(filePath, 'base64')
            else
              body.asset.value = fs.readFileSync(filePath, 'utf8')
            self.put api, body, (err) ->
              if err
                err = err + ' | FILE_PATH: ' + disPath filePath
                return callback err
              else
                current.cont.upHash[filePath].hash = fileHash
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
                  key: dirNm + '/' + name.replace('\\', '/')
                  value: fs.readFileSync(filePath, 'utf8')
              self.put api, body, (err) ->
                if err
                  err = err + ' | FILE_PATH: ' + disPath filePath
                  return callback err
                else
                  current.cont.upHash[filePath].hash = fileHash
                  logs 'Success', '更新线上文件成功'
                  bs.reload filePath
                  return callback(null)

      getFileList: (callback) ->
        self = this
        api  = '/themes/' + current.cont.themeID + '/assets'
        self.get api, (err, body) ->
          if err
            return callback err
          else
            themeDir = current.cont.themeDir
            olFiles = {}
            for key, item of body.assets
              if typeof item == 'object'
                if item.type == 'custom'
                  custom = true
                else
                  custom = false
                olFiles[path.resolve(current.cont.themeDir + '/' + item.key)] =
                  id: item.key
                  custom: custom
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
        return callback '列队处理类型错误' + ' | Type: ' + queue.type + ' | FILE_PATH: ' + queue.path

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

      getUpHash: (olFiles, callback) ->
        self = this
        self.getList (err, fileList) ->
          return callback err if err
          upHash     = current.cont.upHash
          themeDir   = current.cont.themeDir
          assetsRE   = new RegExp(winPathRE(themeDir) + '[\\/\\\\]assets')
          tplRE      = new RegExp(winPathRE(themeDir) + '[\\/\\\\]templates')
          snippetsRE = new RegExp(winPathRE(themeDir) + '[\\/\\\\]snippets')
          layoutRE   = new RegExp(winPathRE(themeDir) + '[\\/\\\\]layout')
          configRE   = new RegExp(winPathRE(themeDir) + '[\\/\\\\]config')
          imgRE      = new RegExp('.(png|jpg|gif|jpeg|bmp|webp)$')
          try
            for item in fileList
              if assetsRE.test(item) && imgRE.test(item)
                upHash[item] =
                  hash  : checksum(item)
                  id    : olFiles[item.replace(imgRE, '')]?.id
                  custom: olFiles[item.replace(imgRE, '')]?.custom
              else
                if assetsRE.test(item) || tplRE.test(item) || snippetsRE.test(item) || layoutRE.test(item) || configRE.test(item)
                  upHash[item] =
                    hash  : checksum(item)
                    id    : olFiles[item]?.id
                    custom: olFiles[item]?.custom
          catch e
            return callback '计算文件 Hash 出错' + ' | ' + e
          item = null
          callback null, upHash

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
                return callback(null, bakHash)
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
        callback null
      watch:
        run: (callback) ->
          logs 'Success', 'Watching... ' + current.cont.themeDir
          check = (path) ->
            if data = current.cont.upHash[path]
              try
                hash = checksum path
              catch e
                logs 'Warning', '计算文件 Hash 出错' + ' | ' + e
                return
              if data.hash != hash
                if data.id
                  auto.queue.add 'update', path
                else
                  auto.queue.add 'add', path
            else
              auto.queue.add 'add', path
          watcher.run()
          watcher.watch.on 'add', (path) ->
            logs 'Info', 'Watcher Create - ' + path
            check(path)
          watcher.watch.on 'change', (path) ->
            logs 'Info', 'Watcher Change - ' + path
            check(path)
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
          logs 'Info', 'Queue Add ' + type + ' - ' + path
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
                    if item.id
                      if bakHash[name]
                        if item.hash != bakHash[name].hash
                          current.cont.upHash[name].hash = null
                          self.queue.add 'update', name
                      else
                        current.cont.upHash[name].hash = null
                        self.queue.add 'update', name
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
