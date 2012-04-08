fs = require 'fs'
{spawn} = require 'child_process'
findit = require('findit')

run = (cmd, args) ->
  proc = spawn cmd, args
  proc.stdout.pipe(process.stdout, end: false)
  proc.stderr.pipe(process.stdout, end: false)

testFiles = ->
  files = findit.sync('test')
  (file for file in files when file.match /\.coffee$/)

task 'test', ->
  cmd = './node_modules/.bin/mocha'
  args = ['--compilers', 'coffee:coffee-script', '--colors', '--reporter', 'spec'].concat testFiles()
  run cmd, args

task 'test:watch', ->
  cmd = './node_modules/.bin/mocha'
  args = ['--watch', '--growl', '--compilers', 'coffee:coffee-script', '--colors', '--reporter', 'spec'].concat testFiles()
  run cmd, args