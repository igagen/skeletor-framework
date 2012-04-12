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

class ObjectModel extends Module
  @include Events

  @copy: (src, target) ->
    for attr, val of src
      if typeof val == 'object'
        target[attr] = {}
        @copy(src[attr], target[attr])
      else
        target[attr] = val

  constructor: () ->
    super
    @attrs = {}

  getLeaf: (obj, attr) ->
    attrs = attr.split('.')
    leafAttr = attrs.pop()
    for a in attrs
      obj[a] ?= {}
      obj = obj[a]
    [obj, leafAttr]

  get: (attr) ->
    [obj, leafAttr] = @getLeaf(@attrs, attr)
    obj[leafAttr]

  set: (attr, val) ->
    [obj, leafAttr] = @getLeaf(@attrs, attr)
    obj[leafAttr] = val
    @trigger 'change'
    @trigger "change:#{attr}"

  toJSON: ->
    json = {}
    @constructor.copy @attrs, json
    json

class ArrayModel extends Module
  @include Events

  constructor: ->
    super
    @array = []

  get: (index) -> @array[index]

  has: (item) -> @array.indexOf(item) != -1

  count: -> @array.length

  add: (items...) ->
    @array.push.apply @array, items
    @trigger 'add', items

  remove: (item) ->
    loop
      index = @array.indexOf item
      if index == -1
        break
      else
        @array.splice(index, 1)
        @trigger 'remove', item, index

  removeAt: (index) ->
    item = @array[index]
    @array.splice index, 1
    @trigger 'remove', item, index

  toJSON: -> @array.slice(0)

class Model extends Module
  @include Events
  @attrs: {}

  constructor: ->
    super

    @attrs = {}

    @defineAccessors(@, @attrs, @constructor.attrs, '')

  defineAccessors: (src, target, attrs, path) ->
    self = @
    for attr, attrType of attrs
      do (attr, path) =>
        if typeof attrType == 'object'
          target[attr] = { attrs: {} }
          target[attr].attrs[k] = v for k, v of target[attr] when k != 'attrs'

          Object.defineProperty src, attr, { get: -> target[attr] }

          @defineAccessors(target[attr], target[attr].attrs, attrs[attr], "#{path}#{attr}.")
        else if typeof attrType == 'function'
          switch attrType.name
            when 'Object'
              target[attr] = new ObjectModel()
              Object.defineProperty src, attr, { get: -> target[attr] }
            when 'Array'
              target[attr] = new ArrayModel()
              Object.defineProperty src, attr, { get: -> target[attr] }
            when 'Number', 'String', 'Boolean'
              Object.defineProperty src, attr,
                get: -> target[attr]
                set: (val) ->
                  target[attr] = val
                  self._onSet("#{path}#{attr}", val)
            else
              # Nested Model
              target[attr] = new attrType()
              Object.defineProperty src, attr, { get: -> target[attr] }

  _onSet: (attr, val) ->
    @trigger 'change'
    @trigger "change:#{attr}"

  _getLeaf: (attr) ->
    attrs = attr.split('.')
    leafAttr = attrs.pop()
    obj = @attrs
    for a in attrs
      obj[a] ?= {}
      obj[a].attrs ?= {}
      obj = obj[a].attrs
    [obj, leafAttr]

  get: (attr) ->
    [obj, leafAttr] = @_getLeaf(attr)
    obj[leafAttr]

  set: (attr, val) ->
    [obj, leafAttr] = @_getLeaf(attr)
    obj[leafAttr] = val
    @_onSet(attr, val)

  toJSON: ->
    convert = (src, target) ->
      for k, v of src
        if k == 'attrs'
          convert(v, target)
        else
          if typeof v == 'object'
            target[k] = {}
            convert(src[k], target[k])
          else
            target[k] = v

    json = {}
    convert(@attrs, json)
    json

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
    if elemAttr == 'data'
      modelAttrs = modelAttr.split(',')
      for modelAttr in modelAttrs
        elemAttr = "data-#{modelAttr}"
        @registerDataBind(model, modelAttr, elem, elemAttr)

    tagName = elem.tagName.toLowerCase()
    $elem = $(elem)

    switch tagName
      when 'input'
        elemAttr ||= 'val'
      else
        elemAttr ||= 'text'

    # Initialize element with model value
    val = model.get(modelAttr)
    Controller.setElem($elem, elemAttr, val)

    # Update element on model change
    model.bind "change:#{modelAttr}", ->
      Controller.setElem($elem, elemAttr, @get(modelAttr))
      animateFn = $elem.data('animate')
      $elem[animateFn]() if animateFn?

    # Update model on form input change
    if tagName == 'input'
      $elem.bind 'change keyup', -> model.set(modelAttr, $elem.val())


root.Model = Model
root.ObjectModel = ObjectModel
root.ArrayModel = ArrayModel
root.Controller = Controller