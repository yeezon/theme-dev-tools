
ipc = require 'ipc'

# 全局变量
_uiData = null
isFirst = true
items   = null
popup   = null
logs    = null
tips    = null
app_top = null
nav     = null

eLogsCont = document.querySelector '.logs-cont'

# 方程
_logs = (type, msg) ->
  if logs
    if logs.$data.logs.length > 1000
      logs.$data.logs = []
    logs.$data.log.type = type
    logs.$data.log.msg  = msg
    logs.$data.logs.push
      type: type
      msg : msg

_tips = (type, msg) ->
  date      = (new Date()).getTime()
  obj       = JSON.parse(JSON.stringify tips.$data.tips)
  obj[date] =
    date: date
    type: type
    msg : msg
  tips.$data.tips = obj

# 事件

## 消息
ipc.on 'Success', (msg) ->
  switch msg
    when 'init_data'
      ipc.send 'get_ui_data'
    when 'run_item'
      items.$data.lock = null
      _logs 'Success', '运行项目成功'
    when 'stop_item'
      items.$data.runMark = null
      items.$data.lock    = null
      _logs 'Success', '停止项目成功'
    when 'add_store'
      popup.$data.addStore  = false
      popup.$data.noneStore = false
      popup.$data.delMark   = null
      popup.$data.upStores  =
        active: false
        domain: ''
        name: ''
        app_key: ''
        app_secret: ''
    when 'del_store'
      popup.$data.noneStore = true
      popup.$data.loadingStore = false
      popup.$data.delMark   = null
      for k, i of _uiData.stores
        popup.$data.noneStore = false
        break
    when 'up_store'
      popup.$data.addStore = false
      popup.$data.delMark  = null
      popup.$data.upStores =
        active: false
        domain: ''
        name: ''
        app_key: ''
        app_secret: ''
    when 'set_item'
      popup.$data.itemState.loading = false
      popup.$data.item.conf.store   = popup.$data.itemState.slcStore
      popup.$data.item.conf.theme   = popup.$data.itemState.slcTheme
    when 'add_item'
      _logs 'Success', msg
    when 'del_item'
      _logs 'Success', msg
    when 'get_theme'
      _logs 'Success', msg
    when 'del_tip'
      _logs 'Success', msg
    when 'set_tag_active'
      _logs 'Success', msg

ipc.on 'Error', (msg) ->
  switch msg
    when 'init_data'
      _logs 'Error', msg
    when 'run_item'
      items.$data.runMark = null
      items.$data.lock    = null
      _logs 'Error', '运行项目失败'
    when 'stop_item'
      items.$data.lock = null
      _logs 'Error', '停止项目失败'
    when 'add_store'
      popup.$data.loadingStore = false
      popup.$data.errStore = true
    when 'del_store'
      popup.$data.loadingStore = false
      popup.$data.errStore = true
    when 'up_store'
      popup.$data.loadingStore = false
      popup.$data.errStore = true
    when 'set_item'
      popup.$data.itemState.loading = false
      popup.$data.itemState.err     = true
    when 'add_item'
      _logs 'Error', msg
    when 'del_item'
      _logs 'Error', msg
    when 'get_theme'
      popup.$data.itemState.themes       = {}
      popup.$data.itemState.slcTheme     = null
      popup.$data.itemState.slcThemeName = null
      popup.$data.itemState.slcThemeShow = false
      popup.$data.itemState.loading      = false
      popup.$data.itemState.err          = true
    when 'del_tip'
      _logs 'Error', msg
    when 'set_tag_active'
      _logs 'Error', msg

ipc.on 'logs', (obj) ->
  _logs obj.type, obj.msg

ipc.on 'tips', (obj) ->
  _tips obj.type, obj.msg


## 处理

ipc.on 'set_ui_data', (data) ->
  _uiData            = data.autoData
  _uiData['current'] = data.current
  _uiData['env']     = data.env
  if isFirst
    runUI()
    isFirst = false
    _logs 'Success', '程序启动成功'
  else
    tips.$data.tips    = _uiData.tips
    items.$data.items  = _uiData.items
    items.$data.env    = _uiData.env
    items.$data.tags   = _uiData.tags
    popup.$data.stores = _uiData.stores
    popup.$data.env    = _uiData.env
    nav.$data.items    = _uiData.items
    nav.$data.current  = _uiData.current
    nav.$data.tags     = _uiData.tags

ipc.on 'set_theme', (data) ->
  popup.$data.itemState.slcStore       = popup.$data.itemState.slcStore
  popup.$data.itemState.slcStoreName   = popup.$data.itemState.slcStoreName
  popup.$data.itemState.slcStoreActive = false
  popup.$data.itemState.slcThemeShow   = true
  popup.$data.itemState.slcTheme       = popup.$data.itemState.slcTheme
  popup.$data.itemState.slcThemeName   = data[popup.$data.itemState.slcTheme]?.name || null
  popup.$data.itemState.slcThemeActive = false
  popup.$data.itemState.themes         = data
  popup.$data.itemState.loading        = false
  popup.$data.itemState.err            = false
  popup.$data.itemState.set            = false

# MVVM Filter

# Vue.filter('concat', function (value, key) {
#   // `this` points to the Vue instance invoking the filter
#   return value + this[key]
# })

runUI = ->

  app_top = new Vue
    el: '#app_top'
    data:
      n: 0
    methods:
      exit: (e) ->
        ipc.send 'quit_app'
      hide: (e) ->
        ipc.send 'hide_app'

  nav = new Vue
    el: '#nav'
    data:
      items  : _uiData.items
      current: _uiData.current
      tags   : _uiData.tags
      run    : null
      active : 'all'
    created: ->
      self = this
      if self.current
        tag = self.items[self.current.themeDir].tag
        self.run        = tag
        self.active     = tag
        items.$data.tag = tag
    methods:
      all: ->
        self = this
        self.active = 'all'
        items.$data.tag = 'all'
        ipc.send 'set_tag_active', 'all'
      star: ->
        self = this
        self.active = 'star'
        items.$data.tag = 'star'
        ipc.send 'set_tag_active', 'star'
      manage: ->
        self = this
        self.active = 'manage'
        items.$data.tag = 'manage'
        ipc.send 'set_tag_active', 'manage'
      dev: ->
        self = this
        self.active = 'dev'
        items.$data.tag = 'dev'
        ipc.send 'set_tag_active', 'dev'
      appSet: ->
        popup.$data.isAppSet = !popup.$data.isAppSet
        popup.$data.addStore = false

  items = new Vue
    el: '#items'
    data:
      runMark: null
      lock   : false
      delMark: null
      active : null
      env    : _uiData.env
      items  : _uiData.items
      tag    : 'all'
    methods:
      run: (item) ->
        self = this
        if !self.lock
          if self.runMark
            if self.runMark == item.path
              ipc.send 'stop_item'
          else
            self.runMark = item.path
            self.lock    = item.path
            ipc.send 'run_item',
              themeDir: item.path
              storeURI: item.conf.store
              themeID : item.conf.theme
      stop: (item)->
        self = this
        self.lock = item.path
        ipc.send 'stop_item'
      del: (item) ->
        self = this
        if item.path == self.delMark
          ipc.send 'del_item', item.path
        else
          self.delMark = item.path
      out: ->
        self = this
        self.delMark = null
      click: (item) ->
        self = this
        self.active = item.path
      itemSet: (item) ->
        self = this
        popup.$data.isItemSet = !popup.$data.isItemSet
        popup.$data.itemState =
          slcStore      : item.conf.store || null
          slcStoreName  : _uiData.stores[item.conf.store]?.name || null
          slcStoreActive: false
          slcThemeShow  : false
          slcTheme      : item.conf.theme || null
          slcThemeName  : null
          slcThemeActive: false
          themes        : {}
          loading       : if item.conf.store then true else false
          err           : false
          set           : false
        popup.$data.item =
          path: item.path
          tag: item.tag
          conf:
            store: item.conf.store
            theme: item.conf.theme
        if item.conf.store
          ipc.send 'get_theme', item.conf.store
      open_dir: (path, evt) ->
        console.log 111
        if !evt.currentTarget.classList.contains('disabled')
          console.log 222
          ipc.send 'open_dir', path
      open_uri: (path, evt) ->
        console.log 111
        if !evt.currentTarget.classList.contains('disabled')
          console.log 222
          ipc.send 'open_uri', path

  logs = new Vue
    el: '#logs'
    data:
      active: false
      log:
        type: null
        msg : null
      logs: []
    methods:
      open: ->
        self = this
        self.active = !self.active
        setTimeout ->
          eLogsCont.scrollTop = eLogsCont.scrollHeight
        , 10

  tips = new Vue
    el: '#tips'
    data:
      tips: _uiData.tips
    methods:
      del: (tip) ->
        ipc.send 'del_tip', tip.date


  popup = new Vue
    el: '#popup'
    data:
      delMark: null
      isAppSet: false
      isItemSet: false
      addStore: false
      loadingStore: false
      errStore: false
      noneStore: true
      env: _uiData.env
      stores: _uiData.stores
      upStores:
        active: false
        domain: ''
        name: ''
        app_key: ''
        app_secret: ''
      item:
        path: ''
        tag: ''
        conf:
          store: ''
          theme: ''
      itemState:
        slcStore: null
        slcStoreName: null
        slcStoreActive: false
        slcThemeShow: false
        slcTheme: null
        slcThemeName: null
        slcThemeActive: false
        themes: {}
        loading: false
        err: false
        set: false
    created: ->
      self = this
      for k, i of _uiData.stores
        self.noneStore = false
        break
    methods:
      add_store: ->
        self = this
        self.loadingStore = true
        data =
          app_key   : self.upStores.app_key
          app_secret: self.upStores.app_secret
        if self.upStores.active
          data['domain'] = self.upStores.domain
          ipc.send 'up_store', data
        else
          ipc.send 'add_store', data
      del_store: (item) ->
        self = this
        self.loadingStore = true
        if item.domain == self.delMark
          ipc.send 'del_store', item.domain
        else
          self.delMark = item.domain
      close_add: ->
        self = this
        self.upStores = false
        self.addStore = false
      open_add_store: ->
        self = this
        self.addStore = true
        self.loadingStore = false
        self.errStore = false
        self.upStores.active = false
      open_up_store: (item) ->
        self = this
        self.addStore = true
        self.loadingStore = false
        self.errStore = false
        self.upStores =
          active: true
          domain: item.domain
          name: item.name
          app_key: ''
          app_secret: ''
      out: ->
        self = this
        self.delMark = null
      open_slc_store: ->
        self = this
        for k, v of self.stores
          self.itemState.slcStoreActive = !self.itemState.slcStoreActive
          break
      slc_store: (store) ->
        self = this
        if self.itemState.slcStore != store.domain
          self.itemState.slcStore     = store.domain
          self.itemState.slcStoreName = store.name
          self.itemState.slcTheme     = null
          self.itemState.loading      = true
          self.itemState.err          = false
          ipc.send 'get_theme', store.domain
        self.itemState.slcStoreActive = false
      slc_theme: (theme) ->
        self = this
        if self.itemState.slcTheme != theme.id
          self.itemState.slcTheme     = theme.id
          self.itemState.slcThemeName = theme.name
        if (self.itemState.slcStore != self.item.conf.store) || (self.itemState.slcTheme != self.item.conf.theme)
          self.itemState.loading = false
          self.itemState.set     = true
        else
          self.itemState.set     = false
        self.itemState.slcThemeActive = false
      up_slc_item: ->
        self = this
        ipc.send 'set_item',
          dir : self.item.path
          data:
            store: self.itemState.slcStore
            theme: self.itemState.slcTheme
        self.itemState.set     = false
        self.itemState.loading = true
      out_slc_store: ->
        self = this
        self.itemState.slcStoreActive = false
      out_slc_theme: ->
        self = this
        self.itemState.slcThemeActive = false
      open_app_data_dir: ->
        self = this
        ipc.send 'open_dir', self.env.DATA_DIR
      open_item_data_dir: ->
        self = this
        ipc.send 'open_dir', self.item.path
      open_dir: (path, evt) ->
        if !evt.currentTarget.classList.contains('disabled')
          ipc.send 'open_dir', path
      open_uri: (path, evt) ->
        if !evt.currentTarget.classList.contains('disabled')
          ipc.send 'open_uri', path

  drop = new Vue
    el: '#drop'
    data:
      active: false
      done: false

  dropHandle = (evt, files) ->
    drop.$data.done = true
    file = files[0]
    if file.type != ''
      return _tips('Warning', '只支持文件夹')
    ipc.send 'add_item', file.path
    setTimeout ->
      drop.$data.active = false
      drop.$data.done   = false
    , 1200

  ( ->
    eBox = document.getElementById 'auto'

    cancelDef = (evt) ->
      evt.preventDefault()

    dropHandler = (evt) ->
      evt.preventDefault()
      dropHandle evt, evt.dataTransfer.files

    # 阻止拖进
    eBox.addEventListener 'dragenter', (evt) ->
      drop.$data.active = true
      evt.preventDefault()
    # 阻止拖来拖去
    eBox.addEventListener 'dragover', (evt) ->
      drop.$data.active = true
      evt.preventDefault()
    # 阻止拖离
    eBox.addEventListener 'dragleave', (evt) ->
      drop.$data.active = false
      evt.preventDefault()
    # 监听拖拽
    eBox.addEventListener 'drop', dropHandler
  )()



