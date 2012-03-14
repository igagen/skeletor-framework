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
    @el.html($('#character-template').html())
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

$ ->
  new CharacterController({el: '#character', model: turan})

# turan.name = 'Turan of the Three Daggers Sept' # Triggers change, change:name events
# character.skills['move-silently'] = 2 # Triggers change, change:skills, change:skills:move-silently
# character.isDirty() # true
# character.toJSON()

# Character.all(cb) # All models from store
# Character.first(conditions, cb) # First model from store, optional conditions
# Character.find({name: 'Turan'}, cb)
# Character.each(cb)

# data-bind='html name', 'class skills:move-silently', 'text languages'