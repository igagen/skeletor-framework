rootPath = '../'
{Model, ObjectModel, ArrayModel} = require("#{rootPath}/skeletor")
assert = require 'assert'
sinon = require 'sinon'
require 'should'
util = require 'util'

class Abilities extends Model
  @attrs:
    str: Number
    dex: Number
    con: Number
    int: Number
    wis: Number
    cha: Number

class Character extends Model
  @attrs:
    name: String
    level: Number
    # abilities: Abilities
    # skills: Object
    # languages: Array
    wealth:
      platinum: Number
      gold: Number
      silver: Number
      copper: Number
      nested:
        bla: Number


describe 'ObjectModel', ->
  describe 'Events', ->
    it 'should trigger appropriate change events', ->
      changeHandler = sinon.spy()
      changeABCHandler = sinon.spy()
      objectModel = new ObjectModel()
      objectModel.bind 'change', changeHandler
      objectModel.bind 'change:a.b.c', changeABCHandler

      objectModel.set('a.b.c', 'bla')

      changeHandler.callCount.should.equal 1
      changeABCHandler.callCount.should.equal 1

  describe 'Accessors', ->
    it 'should allow access to any attributes', ->
      objectModel = new ObjectModel()

      objectModel.set('a.b.c', 'bla')
      objectModel.get('a.b.c').should.eql 'bla'
      objectModel.toJSON().a.b.c.should.eql 'bla'

describe 'ArrayModel', ->
  it 'should work', ->
    arrayModel = new ArrayModel()
    arrayModel.add('a')
    arrayModel.add('b')
    arrayModel.count().should.eql 2
    arrayModel.get(0).should.eql 'a'
    arrayModel.has('a').should.be.true
    arrayModel.toJSON().should.eql ['a', 'b']
    arrayModel.remove('a')
    arrayModel.toJSON().should.eql ['b']

describe 'Model', ->
  describe 'Accessors', ->
    it 'should work', ->
      model = new Character()

      model.set 'name', 'Turan'
      model.name.should.eql 'Turan'
      model.level = 10
      model.get('level').should.eql 10

      model.set 'wealth.platinum', 5
      model.get('wealth.platinum').should.eql 5
      model.wealth.platinum.should.eql 5
      model.wealth.gold = 100
      model.get('wealth.gold').should.eql 100
      model.wealth.nested.bla = 3
      model.set('custom', 10000)
      model.set('a.b.c', 999)

      json = model.toJSON()
      json.a.b.c.should.eql 999
      json.name.should.eql 'Turan'
      json.wealth.gold.should.eql 100

  describe 'Events', ->
    it 'should work', ->
      changeHandler = sinon.spy()
      changeABCHandler = sinon.spy()
      changeNameHandler = sinon.spy()
      changeGoldHandler = sinon.spy()
      model = new Character()
      model.bind 'change', changeHandler
      model.bind 'change:a.b.c', changeABCHandler
      model.bind 'change:name', changeNameHandler
      model.bind 'change:wealth.gold', changeGoldHandler

      model.set('a.b.c', 'bla')
      model.wealth.gold = 5
      model.set('wealth.gold', 10)

      changeHandler.callCount.should.equal 3
      changeABCHandler.callCount.should.equal 1
      changeGoldHandler.callCount.should.equal 2

# describe 'Model', ->
#   before ->
#     @character = new Character()

#   describe 'accessors', ->
#     it 'just works', ->
#       # Simple attr access

#       assert.equal @character.name, null
#       assert.equal @character.get('name'), null
#       assert.equal @character.get('nonExistantAttribute'), undefined
#       assert.equal @character.wealth.gold, null
#       @character.set('name', 'Turan')
#       @character.get('name').should.equal 'Turan'
#       @character.name.should.equal 'Turan'
#       @character.name = 'Coeur'
#       @character.get('name').should.equal 'Coeur'
#       @character.name.should.equal 'Coeur'

#       # Nested attr access

#       @character.set 'wealth.gold', 10
#       @character.get('wealth.gold').should.equal 10
#       @character.wealth.gold.should.equal 10
#       @character.wealth.silver = 5
#       @character.get('wealth.silver').should.equal 5
#       @character.wealth.get('silver').should.equal 5
#       @character.wealth.silver.should.equal 5
#       @character.get('wealth').silver.should.equal 5

#       # Nested model access

#       @character.abilities.str = 18
#       @character.get('abilities.str').should.equal 18
#       @character.set('abilities.dex', 16)
#       @character.abilities.dex.should.equal 16
#       @character.abilities.set('con', 18)
#       @character.abilitieis.con.should.equal 18

#       # Array access

#       @character.languages.should.eql []
#       @character.languages.add 'common'
#       @character.languages.add 'elven'
#       @character.languages.has('common').should.equal true
#       @character.languages.should.eql ['common', 'elven']
#       @character.languages.remove 'elven'
#       @character.languages.should.eql ['common']
#       @character.languages.removeAt 0
#       @character.languages.should.eql []
#       @character.languages.add('dwarven')
#       @character.languages.get(0).should.eql 'dwarven'

#       # Object access

#       @character.skills.should.eql {}
#       @character.skills.set 'climbing', 2
#       @character.skills.climbing.should.eql 2
#       @character.skills.get('climbing').should.eql 2
#       @character.get('skills.climbing').should.eql 2
#       @character.set('skills.swimming', 3)
#       @character.skills.swimming.should.eql 3

#       # JSON

#       emptyJSON =
#         name: null
#         level: null
#         abilities:
#           str: null
#           dex: null
#           con: null
#           int: null
#           wis: null
#           cha: null
#         wealth:
#           platinum: null
#           gold: null
#           silver: null
#           copper: null
#         languages: []
#         skills: {}

#       populatedJSON =
#         name: 'Coeur'
#         level: null
#         abilities:
#           str: 18
#           dex: 16
#           con: 18
#           int: null
#           wis: null
#           cha: null
#         wealth:
#           platinum: null
#           gold: 10
#           silver: 5
#           copper: null
#         languages: ['dwarven']
#         skills:
#           climbing: 2
#           swimming: 3

#       newCharacter = new Character()
#       newCharacter.toJSON().should.eql emptyJSON

#       @character.toJSON().should.eql populatedJSON

#       newCharacter.load populatedJSON
#       newCharacter.toJSON().should.equal populatedJSON

#       new Character(populatedJSON).toJSON().should.eql populatedJSON


  # describe 'events', ->
  #   it 'just works', ->
  #     @character.bind

  # describe '#constructor', ->
  #   it 'initializes the model with the passed attributes', ->
  #     @model.a.should.equal 1
  #     @model.c.nested.should.equal 2
  #     assert.equal @model.b, undefined

  # describe 'getters and setters', ->
  #   it 'allows setting attributes via properties', ->
  #     @model.a = 3
  #     @model.get('a').should.equal 3

  #   it 'allows getting attributes via properties', ->
  #     @model.set('a', 4)
  #     @model.a.should.equal 4

  #   it 'allows setting nested attributes via properties', ->
  #     @model.c.nested = 3
  #     @model.get('c.nested').should.equal 3

  #   it 'allows getting nested attributes via properties', ->
  #     @model.set('c.nested', 4)
  #     @model.get('c.nested').should.equal 4

  # describe '#save', ->
  #   it 'saves the passed record to local storage', ->
  #     @model.save()

  #   it "sets the record's id on create", ->
  #     model = new TestModel()
  #     assert.equal model.id, undefined
  #     model.save()
  #     model.id.should.not.equal undefined

  #   it "does not set the record's id on update", ->
  #     model = new TestModel()
  #     model.save()
  #     id = model.id
  #     model.save()
  #     model.id.should == id