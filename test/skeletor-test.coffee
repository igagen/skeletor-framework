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
    abilities: Abilities
    skills: Object
    languages: Array
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

  describe 'Nested ObjectModel', ->
    it 'should work', ->
      model = new Character()

      model.skills.toJSON().should.eql {}
      model.skills.set 'climbing', 2
      model.skills.get('climbing').should.eql 2

  describe 'Nested ArrayModel', ->
    it 'should work', ->
      model = new Character()

      model.languages.toJSON().should.eql []
      model.languages.add 'common'
      model.languages.add 'elven'
      model.languages.has('common').should.be.true
      model.languages.toJSON().should.eql ['common', 'elven']
      model.languages.remove 'elven'
      model.languages.toJSON().should.eql ['common']
      model.languages.removeAt 0
      model.languages.toJSON().should.eql []
      model.languages.add('dwarven')
      model.languages.get(0).should.eql 'dwarven'

  describe 'Nested Model', ->
    it 'should work', ->
      model = new Character()

      model.abilities.str = 18
      model.abilities.get('str').should.eql 18
      model.abilities.set('dex', 16)
      model.abilities.dex.should.eql 16
