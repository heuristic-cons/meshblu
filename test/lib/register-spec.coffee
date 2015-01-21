_            = require 'lodash'
bcrypt       = require 'bcrypt'
TestDatabase = require '../test-database'

describe 'register', ->
  beforeEach (done) ->
    @sut = require '../../lib/register'
    @updateDevice = sinon.stub()
    TestDatabase.open (error, database) =>
      @database = database
      @devices  = @database.collection 'devices'

      @dependencies = {database: @database, updateDevice: @updateDevice}
      done error

  afterEach ->
    @database.close()

  it 'should be a function', ->
    expect(@sut).to.be.a 'function'

  describe 'when called with no params', ->
    beforeEach (done) ->
      @updateDevice.yields null
      storeDevice = (@error, @device) => done()
      @sut null, storeDevice, @dependencies

    it 'should return a device', ->
      expect(@device).to.exist

    it 'should create a device', (done) ->
      @database.devices.count (error, count) =>
        return done error if error?
        expect(count).to.equal 1
        done()

    it 'should generate a new uuid', ->
      expect(@device.uuid).to.exist

    it 'should generate a new token', ->
      expect(@device.token).to.exist

    it 'should call updateDevice', ->
      expect(@updateDevice).to.have.been.called


    describe 'when called again with no params', ->
      beforeEach (done) ->
        @updateDevice.yields null
        storeDevice = (error, @newerDevice) => done()
        @sut null, storeDevice, @dependencies

      it 'should create a new device', ->
        expect(@newerDevice).to.exist

      it 'should generate a different token', ->
        expect(@newerDevice.token).to.not.equal @device.token

  describe 'when called with a specific uuid', ->
    beforeEach (done) ->
      @updateDevice.yields null
      @sut {uuid: 'some-uuid'}, done, @dependencies

    it 'should create a device with that uuid', (done) ->
      @devices.findOne uuid: 'some-uuid', (error, device) =>
        expect(device).to.exist
        done()

  describe 'when called with a specific token', ->
    beforeEach (done) ->
      @updateDevice.yields null
      storeDevice = (error, @device) => done()
      @sut {token: 'mah-secrets'}, storeDevice, @dependencies

    it 'should call update device with that token', ->
      expect(@updateDevice).to.be.calledWith @device.uuid, {token: 'mah-secrets', uuid: @device.uuid}

  describe 'when called without an online', ->
    beforeEach (done) ->
      @updateDevice.yields null
      @sut {}, done, @dependencies

    it 'should create a device with an online of false', (done) ->
      @devices.findOne (error, device) =>
        expect(device.online).to.be.false
        done()

  describe 'when there is an existing device', ->
    beforeEach (done) ->
      @devices.insert {uuid : 'some-uuid', name: 'Somebody.'}, done

    describe 'trying to create a new device with the same uuid', ->
      beforeEach (done) ->
        @updateDevice.yields null
        storeDevice = (@error, @device) => done()
        @sut {uuid: 'some-uuid', name: 'Nobody.'}, storeDevice, @dependencies

      it 'it should call the callback with an error', ->
        expect(@error).to.exist

    describe 'trying to create a new device with a different uuid', ->
      beforeEach (done) ->
        @updateDevice.yields null
        storeDevice = (@error, @device) => done()
        @sut {uuid: 'some-other-uuid'}, storeDevice, @dependencies

      it 'it create a second device', (done) ->
        @database.devices.count (error, count) =>
          return done error if error?
          expect(count).to.equal 2
          done()

  describe 'when called with just a name', ->
    beforeEach (done) ->
      @updateDevice.yields null
      storeDevice = (error, @device) => done()
      @params = {name: 'bobby'}
      @originalParams = _.cloneDeep @params
      @sut @params, storeDevice, @database

    it 'should not mutate the params', ->
      expect(@params).to.deep.equal @originalParams
