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

  bindData: ->
    if @model?
      @$("*[data-bind]").each (i, elem) =>
        tagName = elem.tagName.toLowerCase()
        $elem = $(elem)
        attr = $elem.data('bind')
        val = @model.get(attr)

        switch tagName
          when 'input'
            # Initialize element
            $elem.val(val)

            # Update model when element changes
            $elem.bind 'change', => @model.set(attr, $elem.val())
            $elem.bind 'keyup', => @model.set(attr, $elem.val())

            # Update element when model changes
            @model.bind "change:#{attr}", ->
              $elem.val(@get(attr))
          else
            # Initialize element
            $elem.text(val)

            # Update element when model changes
            @model.bind "change:#{attr}", ->
              $elem.text(@get(attr))




class Character extends Model
  @attrs
    name: 'string'
    age: 'string'
    skills:
      survival: 'number'
      'move-silently': 'number'
  #   languages: Array
  # @store MemoryStore, options

class CharacterController extends Controller
  constructor: (options) ->
    super(options)

    @render()

  render: ->
    @el.html("<h2 data-bind='name'></h2><input data-bind='name'></input><input data-bind='name'></input>")

    @bindData()


turan = new Character
  name: 'Turan'
  skills:
    'move-silently': 1


turan.bind 'change', ->
  console.log 'change'
turan.bind 'change:name', ->
  console.log "change:name #{@name}"
turan.bind 'change:skills.survival', ->
  console.log "change:skills.survival #{@skills.survival}"


# turan.name = 'Turan of the Three Daggers Sept'

# console.log turan.skills
# turan.name = 'Turan of the Three Daggers Sept'
# turan.skills.survival = 2
# console.log turan.skills.survival
# turan.skills.survival = 2
# turan.set('skills.survival', 3)
# console.log turan.skills.survival
# console.log turan.toJSON()

# turan.set('name', 'Turan')
# turan.name = 'Turaan'
# turan.skills.survival = 2
# turan.set('skills.survival', 3)

new CharacterController({el: 'body', model: turan})

# turan.name = 'Turan of the Three Daggers Sept' # Triggers change, change:name events
# character.skills['move-silently'] = 2 # Triggers change, change:skills, change:skills:move-silently
# character.isDirty() # true
# character.toJSON()

# Character.all(cb) # All models from store
# Character.first(conditions, cb) # First model from store, optional conditions
# Character.find({name: 'Turan'}, cb)
# Character.each(cb)

# data-bind='html name', 'class skills:move-silently', 'text languages'