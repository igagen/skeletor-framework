class Character extends Model
  @attrs:
    name: 'string'
    age: 'string'
    skills:
      survival: 'number'
      'move-silently': 'number'

class CharacterController extends Controller
  constructor: (options) ->
    super(options)

    @render()

  render: ->
    @el.html($('#character-template').html())

    $skills = @$('#skills')
    for id of Character.attrs.skills
      $skills.append("<div class='skill' data-attr='skills.#{id}'><div class='item-points' data-bind='skills.#{id}'></div>#{id.replace(/-/, ' ')}</div>")

    model = @model
    @$('.skill').bind 'click', (e) ->
      attr = $(@).data('attr')
      model.set(attr, (model.get(attr) || 0) + 1)


    @bindData()

$ ->
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

  new CharacterController({el: '#character', model: turan})