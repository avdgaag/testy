class ExpectationFailed
  name: 'ExpectationFailed'
  constructor: (@message) ->

assertions =
  toEqual:         (expected) -> @obj == expected
  toBeTruthy:                 -> @obj
  toBeOfType:      (expected) -> typeof @obj == expected
  toBeFunction:               -> typeof @obj == 'function'
  toBeString:                 -> typeof @obj == 'string'
  toBeNumber:                 -> typeof @obj == 'number'
  toBeArray:                  -> typeof @obj == 'array'
  toBeObject:                 -> typeof @obj == 'object'
  toBeUndefined:              -> typeof @obj == 'undefined'
  toBe:            (expected) -> @obj == expected
  toMatch:         (expected) -> @obj.match expected
  toBeNull:                   -> @obj == null
  toContain:       (expected) -> @obj.indexOf(expected) >= 0
  toBeLessThan:    (expected) -> @obj < expected
  toBeGreaterThan: (expected) -> @obj > expected
  toBeBetween:     (a, b)     -> a < @obj < b

class Expectation
  constructor: (@obj) ->
    @[name] = @createMatcher(name, fn) for name, fn of assertions

  not: ->
    @invertMatcher = true

  createMatcher: (name, fn) ->
    description = name.replace(/([a-z])([A-Z])/, '$1 $2').toLowerCase()
    output = ->
      message = "Expected #{@obj} #{description} #{Array.prototype.slice.call(arguments).join(', ')}"
      passed = fn.apply(@, arguments)
      passed = not passed if @invertMatcher
      throw new ExpectationFailed(message) unless passed


class Context
  constructor: (@subject, @fn, @parent = null) ->
    @before   = []
    @after    = []
    @contexts = []
    @parent?.addSubcontext @
    @

  parse: ->
    @fn?()

  addTest: (description, fn) ->
    @parent?.addTest @fullSubject() + description, fn

  fullSubject: ->
    subject = @subject + " "
    subject = @parent.fullSubject() + " " + subject if @parent?
    subject

  addSubcontext: (context) ->
    @contexts.push context

  addBefore: (fn) ->
    @before.push fn

  addAfter: (fn) ->
    @after.push fn

  beforeTree: ->
    (if @parent? then @parent.beforeTree() else []).concat @before

  afterTree: ->
    (if @parent? then @parent.afterTree() else []).concat @after

  collectMethods: (collection) ->
    -> fn.call(@) for fn in collection

class Suite extends Context
  constructor: ->
    super
    @tests   = []
    @passed  = 0
    @failed  = 0
    @pending = 0

  report: ->
    for test in @tests
      if test.hasFailed
        @failed++
        console.log test.description
      else
        @passed++
    console.log "#{@tests.length} examples, #{@passed} passed, #{@failed} failed"

  
  parse: ->
    super
    @run()

  run: ->
    test.run() for test in @tests
    @report()

  addTest: (description, fn) ->
    @tests.push new Test(
      description,
      fn,
      @,
      @collectMethods(@beforeTree()),
      @collectMethods(@afterTree())
    )

class Test
  constructor: (@description, @body, @context, @before = null, @after = null) ->
    @hasFailed = false
    @failure_message = null

  fail: (message) ->
    @hasFailed = true
    @failure_message = message

  error: (error) ->
    @error = true
    @failure_message = "#{error.name}: #{error.message}"

  run: ->
    try
      @before.call @context
      @body.call   @context
    catch e
      switch e.name
        when 'ExpectationFailed' then @fail(e.message)
        else @error e
    finally
      @after.call  @context

current_context = null

describe = (description, fn) ->
  current_context = if current_context?
    new Context(description, fn, current_context)
  else
    new Suite(description, fn)
  current_context.parse()

before = (fn)              -> current_context.addBefore fn
after  = (fn)              -> current_context.addAfter fn
it     = (description, fn) -> current_context.addTest description, fn
expect = (obj)             -> new Expectation(obj)

describe 'Array', ->
  describe 'with elements', ->
    before ->
      @subject = [1,2]

    it 'should have 2 elements', ->
      expect(@subject.length).toEqual(2)
