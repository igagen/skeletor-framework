root = exports ? this
$ = root.Zepto || root.jQuery

# Utils

type = do ->
  classToType = {}
  for name in "Boolean Number String Function Array Date RegExp Undefined Null".split(" ")
    classToType["[object " + name + "]"] = name.toLowerCase()

  (obj) ->
    strType = Object::toString.call(obj)
    classToType[strType] or "object"

# Events

Events =
  bind: (ev, callback) ->
    evs   = ev.split(' ')
    calls = @hasOwnProperty('_callbacks') and @_callbacks or= {}

    for name in evs
      calls[name] or= []
      calls[name].push(callback)
    this

  one: (ev, callback) ->
    @bind ev, ->
      @unbind(ev, arguments.callee)
      callback.apply(@, arguments)

  trigger: (args...) ->
    ev = args.shift()

    list = @hasOwnProperty('_callbacks') and @_callbacks?[ev]
    return unless list

    for callback in list
      if callback.apply(@, args) is false
        break
    true

  unbind: (ev, callback) ->
    unless ev
      @_callbacks = {}
      return this

    list = @_callbacks?[ev]
    return this unless list

    unless callback
      delete @_callbacks[ev]
      return this

    for cb, i in list when cb is callback
      list = list.slice()
      list.splice(i, 1)
      @_callbacks[ev] = list
      break
    this

moduleKeywords = ['included', 'extended']

class Module
  @include: (obj) ->
    throw('include(obj) requires obj') unless obj
    for key, value of obj when key not in moduleKeywords
      @::[key] = value
    obj.included?.apply(@)
    this

  @extend: (obj) ->
    throw('extend(obj) requires obj') unless obj
    for key, value of obj when key not in moduleKeywords
      @[key] = value
    obj.extended?.apply(@)
    this

  @proxy: (func) ->
    => func.apply(@, arguments)

  proxy: (func) ->
    => func.apply(@, arguments)

  constructor: ->
    @init?(arguments...)

class Model extends Module
  @extend Events

  @records: {}
  @crecords: {}
  @attrs: {}
  @idCounter: 0
  @uid: -> @idCounter++
  @store: (@store) ->

  @find: (id) ->
    record = @records[id]
    if !record and ("#{id}").match(/c-\d+/)
      return @findCID(id)
    throw('Unknown record') unless record
    record.clone()

  @findCID: (cid) ->
    record = @crecords[cid]
    throw('Unknown record') unless record
    record.clone()

  # Instance

  constructor: (attrs) ->
    super

    console.warn "#{@className()}: No attributes defined" unless Object.keys(@constructor.attrs).length > 0
    @attrs = JSON.parse(JSON.stringify(attrs || {}))
    @_defineAccessors(@, @attrs, @constructor.attrs, '')
    @cid ?= 'c-' + @constructor.uid()

  load: (attrs) ->
    setAttr = (obj, attrs) ->
      for attr, val of attrs
        if type(obj[attr]) == 'object'
          setAttr(obj[attr], attrs[attr])
        else
          obj[attr] = val

    setAttr(@, attrs)

  isNew: -> not @exists()
  isValid: -> not @validate()
  validate: ->
  exists: -> @id && @id of @constructor.records
  className: -> @constructor.name

  dup: (newRecord) ->
    result = new @constructor(@attributes())
    if newRecord is false
      result.cid = @cid
    else
      delete result.id
    result

  clone: ->
    Object.create(@)

  _defineAccessors: (src, target, attrs, path) ->
    self = @
    for attr, attrType of attrs
      do (attr, path) =>
        if type(attrs[attr]) == 'string'
          Object.defineProperty src, attr,
            get: -> target[attr]
            set: (val) ->
              target[attr] = val
              self._onSet("#{path}#{attr}", val)
        else # Nested attributes
          target[attr] ||= {}
          target[attr].attrs = {}
          for k, v of target[attr] when k != 'attrs'
            target[attr].attrs[k] = v

          Object.defineProperty src, attr,
            get: -> target[attr]

          @_defineAccessors(target[attr], target[attr].attrs, attrs[attr], "#{path}#{attr}.")

  store: -> @constructor.store

  save: (options = {}, cb = null) ->
    unless options.validate is false
      error = @validate()
      if error
        @trigger('error', error)
        return false

    @trigger('beforeSave', options)
    if @isNew() then @_create(options, cb) else @_update(options, cb)

    @trigger('save', options)
    @

  updateAttribute: (name, value) ->
    @[name] = value
    @save()

  updateAttributes: (atts, options) ->
    @load(atts)
    @save(options)

  _create: (options, cb) ->
    @trigger('beforeCreate', options)

    if @store()?
      @store().create(@, cb)
    else
      @id = @cid

    record = @dup(false)
    @constructor.records[@id] = record
    @constructor.crecords[@cid] = record

    clone = record.clone()
    clone.trigger('create', options)
    clone.trigger('change', 'create', options)
    clone

  _update: (options, cb) ->
    @trigger('beforeUpdate', options)
    @constructor.records[@id].load @attributes()

    @store()?.update(@, cb)

    @trigger('update', options)
    @trigger('change', 'update', options)
    @

  _onSet: (attr, val) ->
    @trigger 'change'
    @trigger "change:#{attr}"

  _getLeaf: (attr) ->
    attrs = attr.split('.')
    leafAttr = attrs.pop()
    obj = @
    obj = obj[a] for a in attrs
    [obj, leafAttr]

  get: (attr) ->
    [obj, leafAttr] = @_getLeaf(attr)
    obj[leafAttr]

  set: (attr, val) ->
    [obj, leafAttr] = @_getLeaf(attr)
    obj[leafAttr] = val

  attributes: -> @toJSON()

  toJSON: ->
    addAttrs = (obj, attrs, js) ->
      for k, v of attrs
        if type(v) == 'object'
          js[k] = {}
          addAttrs(obj[k], attrs[k], js[k])
        else
          js[k] = obj[k] if obj[k]?
      js

    addAttrs(@, @constructor.attrs, {})

  eql: (rec) ->
    !!(rec and rec.constructor is @constructor and
      (rec.id is @id or rec.cid is @cid))

  # Event Instance Methods

  bind: (events, callback) ->
    @constructor.bind events, binder = (record) =>
      if record && @eql(record)
        callback.apply(@, arguments)
    @constructor.bind 'unbind', unbinder = (record) =>
      if record && @eql(record)
        @constructor.unbind(events, binder)
        @constructor.unbind('unbind', unbinder)
    binder

  one: (events, callback) ->
    binder = @bind events, =>
      @constructor.unbind(events, binder)
      callback.apply(@)

  trigger: (args...) ->
    args.splice(1, 0, @)
    @constructor.trigger(args...)

  unbind: ->
    @trigger('unbind')


class LocalStore
  constructor: (klass) -> @className = klass.name
  count: -> @_get("#{@className}.count") || 0
  _setCount: (count) -> @_set "#{@className}.count", count

  _get: (key) -> localStorage[key]
  _set: (key, value) -> localStorage[key] = value

  create: (record, cb) ->
    record.id = @count() + 1
    @_setCount(record.id)

    @_set "#{@className}.#{record.id}", JSON.stringify(record)
    cb(true) if cb?

  update: (record, cb) ->
    @_set "#{@className}.#{record.id}", JSON.stringify(record)
    cb(true) if cb?

class Controller extends Module
  @include Events

  tag: 'div'

  constructor: (options) ->
    @options = options

    for key, value of @options
      @[key] = value

    @el = document.createElement(@tag) unless @el
    @el = $(@el)

    @el.addClass(@className) if @className
    @el.attr(@attributes) if @attributes

    @registerEventHandlers()

    super

  $: (selector) -> $(selector, @el)

  append: (elements...) ->
    elements = (e.el or e for e in elements)
    @el.append(elements...)
    @refreshElements()
    @el

  appendTo: (element) ->
    @el.appendTo(element.el or element)
    @refreshElements()
    @el

  prepend: (elements...) ->
    elements = (e.el or e for e in elements)
    @el.prepend(elements...)
    @refreshElements()
    @el

  @setElem: (elem, attr, val) ->
    val ?= ''

    console.log 'setElem', attr, val

    if attr.match(/data-\w+/)
      return elem.attr(attr, val)

    switch attr
      when 'val' then elem.val(val)
      when 'text' then elem.text(val)
      when 'html' then elem.html(val)
      when 'class'
        elem.attr('class', val)
      else
        klass = attr.replace(/\./, '')
        if klass[0] == '!'
          klass = klass.slice(1)
          val = !val

        if val
          elem.addClass(klass)
        else
          elem.removeClass(klass)

  updateSelect: ($select) ->
    modelAttr = $select.data('select')
    optionAttr = 'selected'
    val = @model.get(modelAttr)
    $options = $select.find("[data-option]")
    $options.removeClass(optionAttr)
    $select.find("[data-option='#{val}']").addClass(optionAttr)

  registerEventHandlers: ->
    self = @
    tap = if $.os.ipad then 'touchstart' else 'click'
    for eventDescriptor, eventHandler of @events
      match = eventDescriptor.match(/(\w+) (.+)/)
      event = match[1]
      event = tap if event == 'tap'
      selector = match[2]

      if selector == 'document' || selector == 'window'
        selector = document if selector == 'document'
        selector = window if selector == 'window'
        bindFn = 'bind'
      else
        bindFn = 'live'

      do (eventHandler) ->
        $(selector)[bindFn] event, (evt) ->
          $elem = $(@)
          self[eventHandler](evt, $elem)

  bindData: ->
    if @model?
      @$('*[data-bind]').each (i, elem) =>
        $elem = $(elem)
        dataBind = $elem.data('bind')
        dataBindStatements = dataBind.split ';'
        for dataBindStatement in dataBindStatements
          dataBindStatement = dataBindStatement.trim()
          attrs = dataBindStatement.split ' '
          unless attrs.length == 1 || attrs.length == 2
            return console.error "Invalid data-bind: '#{dataBindStatement}'"

          modelAttr = attrs[0]
          elemAttr = attrs[1]

          @registerDataBind(@model, modelAttr, elem, elemAttr)

      @$('*[data-select]').each (i, elem) =>
        $select = $(elem)
        $options = $select.find("[data-option]")
        modelAttr = $select.data('select')

        # Set initial value
        @updateSelect $select

        # Set value on click
        self = @
        $options.bind 'click', -> self.model.set modelAttr, $(@).data('option')

        # Update on model changes
        @model.bind "change:#{modelAttr}", => @updateSelect $select

  registerDataBind: (model, modelAttr, elem, elemAttr) ->
    console.log 'modelAttr', modelAttr
    console.log 'elemAttr', elemAttr

    tagName = elem.tagName.toLowerCase()
    $elem = $(elem)

    if elemAttr == 'data'
      elemAttr = "data-#{modelAttr}"

    switch tagName
      when 'input'
        elemAttr ||= 'val'
      else
        elemAttr ||= 'text'

    # Initialize element with model value
    val = model.get(modelAttr)
    Controller.setElem($elem, elemAttr, val)

    # Update element on model change
    model.bind "change:#{modelAttr}", -> Controller.setElem($elem, elemAttr, @get(modelAttr))

    # Update model on form input change
    if tagName == 'input'
      $elem.bind 'change keyup', -> model.set(modelAttr, $elem.val())




root.Model = Model
root.Controller = Controller
root.LocalStore = LocalStore