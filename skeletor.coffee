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

  @attrs: (attrs) -> @attrs = attrs if attrs?

  @uid: -> @idCounter++

  # Instance

  constructor: (attrs) ->
    super
    @load attrs
    @cid ?= 'c-' + @constructor.uid()

  load: (attrs) ->
    @attrs = JSON.parse(JSON.stringify(attrs))

    @defineAccessors(@, @attrs, @constructor.attrs, '')

  defineAccessors: (src, target, attrs, path) ->
    self = @
    for attr, type of attrs
      do (attr, path) =>
        if typeof attrs[attr] == 'string'
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

          @defineAccessors(target[attr], target[attr].attrs, attrs[attr], "#{path}#{attr}.")

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

  toJSON: ->
    addAttrs = (obj, attrs, js) ->
      for k, v of attrs
        if typeof v == 'object'
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

  bindData: ->
    if @model?
      @$("*[data-bind]").each (i, elem) =>
        tagName = elem.tagName.toLowerCase()
        $elem = $(elem)
        dataBind = $elem.data('bind')
        dataBindMatch = dataBind.match(/([\w.\-]+)[ ]?([\w.!\-]+)?/)
        unless dataBindMatch
          console.error "Invalid data-bind attribute: '#{dataBind}'"
          return

        if dataBindMatch.length == 3 && dataBindMatch[2]
          modelAttr = dataBindMatch[1]
          elemAttr = dataBindMatch[2]
        else
          modelAttr = dataBindMatch[1]

        val = @model.get(modelAttr)

        switch tagName
          when 'input'
            elemAttr ||= 'val'

            Controller.setElem($elem, elemAttr, val)
            $elem.bind 'change keyup', => @model.set(modelAttr, $elem.val())
            @model.bind "change:#{modelAttr}", -> Controller.setElem($elem, elemAttr, @get(modelAttr))
          else
            elemAttr ||= 'text'

            Controller.setElem($elem, elemAttr, val)
            @model.bind "change:#{modelAttr}", -> Controller.setElem($elem, elemAttr, @get(modelAttr))


window.Model = Model
window.Controller = Controller