###############################################################
# Data Source
###############################################################
Neptune.parseDataSource = Ember.Object.create({

  # init
  #    initialize the global Parse object
  init: ->
    this._super()
    Parse.initialize this.parseApplicationId, this.parseJavaScriptKey

    # include facebook script
    ((d) ->
      js = undefined
      id = 'facebook-jssdk'
      ref = d.getElementsByTagName('script')[0]
      return  if d.getElementById(id)
      js = d.createElement('script')
      js.id = id
      js.async = true
      js.src = '//connect.facebook.net/en_US/all.js'
      ref.parentNode.insertBefore js, ref
    ) document

    window.fbAsyncInit = ->

      Parse.FacebookUtils.init
        appId: '650765618296184' # Facebook App ID
        cookie: true # enable cookies to allow Parse to access the session
        xfbml: false # parse XFBML


  # application id property to connect to parse
  parseApplicationId: 'jRt3oPjIvmawp4zdZdFXgH93X9Rir9CT3wPaJhkK'

  # javascript key property to connect to parse
  parseJavaScriptKey: 'wNiz7v3vAD6EH5p5B65oBxqgeF5E5Tb3mI3r66tf'

  # login - attempt to log a user into the parse system
  #   parameters
  #     username - the username for the user logging in
  #     password - the password for the user logging in
  #     callback - callback function to return the user and/or error
  #   returns
  #     success - Neptune.User object, null
  #     failure - null, Neptune.Error object
  login: (username, password, callback) ->
    Parse.User.logIn username, password,
      success: (data) =>
        callback(this.getCurrentUser, null)
      error: (error) =>
        callback(null, this.getError(error.code, error.message, 'ERROR', 'Neptune.parseDataSource-login'))

  # fbLogin - attempt to log a user into the parse system via Facebook
  #   parameters
  #     callback - callback function to return the user and/or error
  #   returns
  #     success - Neptune.User object, null
  #     failure - null, Neptune.Error object
  fbLogin: (callback) ->
    Parse.FacebookUtils.logIn null,
      success: (user) ->
        # user is new
        unless user.existed()
          callback(user, null)
        # user has registered in the past
        else
          callback(user, null)

      error: (user, error) ->
        callback(null, this.getError(error.code, error.message, 'ERROR', 'Neptune.parseDataSource-login'))

  # logout - log the current user out of the system
  #   parameters - none
  #   returns - nothing
  logout: () ->
    Parse.User.logOut()

  # register - register a user into the system
  #   parameters
  #     user - Neptune.User object of the person attempting to register
  #     callback - callback function to return the user and/or error
  #   returns
  #     success - objectId of the Parse User in the database, null
  #     failure - null, Neptune.Error object
  register: (user, callback) ->
    parseUser = new Parse.User()
    parseUser.set 'username', user.email
    parseUser.set 'password', user.password
    parseUser.set 'firstName', user.firstName
    parseUser.set 'lastName', user.lastName
    parseUser.set 'email', user.email

    parseUser.signUp null,
      success: (data) =>
        callback(data, null)
      error: (error) =>
        callback(null, this.getError(error.code, error.message, 'ERROR', 'Neptune.parseDataSource-register'))

  # requestPasswordReset - send out a reset password email to the user
  #   parameters
  #     email - email to send reset password to
  #     callback - callback function to return the data and/or error
  #   returns
  #     success - null, null
  #     failure - null, Neptune.Error object
  requestPasswordReset: (email, callback) ->
    Parse.User.requestPasswordReset email,
      success: =>
        callback(null, null)
      # Password reset request was sent successfully
      error: (error) =>
        callback(null, this.getError(error.code, error.message, 'ERROR', 'Neptune.parseDataSource-requestPasswordReset'))

  # updateUser - update the current user in the system
  #   parameters
  #     user - Neptune.User object with the updated information
  #     callback - callback function to return the data and/or error
  #   returns
  #     success - the Neptune.User object, null
  #     failure - null, Neptune.Error object
  updateUser: (user, callback) ->
    parseUser = Parse.User.current()

    if (parseUser)
      #if we don't set the username and email to themselves, for some reason the Parse.User.current() object loses these values
      parseUser.set 'username', parseUser.get 'username'
      parseUser.set 'email', parseUser.get 'email'

      parseUser.set 'firstName', user.firstName
      parseUser.set 'lastName', user.lastName

      parseUser.save null,
        success: (data) =>
          callback(this.getCurrentUser(), null)
        error: (error) =>
          callback(null, getError(error.code, error.message, 'Neptune.parseDataSource-updateUser'))
    else
      callback(data, this.getError(null, 'No user found', 'Neptune.parseDataSource-updateUser'))

  # getCurrentUser - wrapper to return the current Parse user transformed into a Neptune.User object
  #   returns - a Neptune.User object if there is a current user, otherwise null
  getCurrentUser: ->
    if (Parse.User.current())
      # user is from facebook
      ###if Parse.User.current().get('authData').facebook
        return Neptune.User.create(
          objectId: Parse.User.current().id
        )

      else###
      return Neptune.User.create(
        objectId: Parse.User.current().id
        userName: Parse.User.current().attributes.username
        firstName: Parse.User.current().attributes.firstName
        lastName: Parse.User.current().attributes.lastName
      )
    else
      #FB.getLoginStatus (status) ->
      #  console.log status

      return null

  # getEmailMessages - return email messages sent out by the current user
  #   parameters
  #     callback - callback function to return the data and/or error
  #   returns
  #     success - Ember.Array of Neptune.Message objects, null
  #     failure - null, Neptune.Error object
  getEmailMessages: (callback) ->
    # setup a Parse query to search for all messages for the user passed in ordered by update date
    EmailMessage = Parse.Object.extend('EmailMessage')
    emailMessageQuery = new Parse.Query(EmailMessage)
    emailMessageQuery.descending 'updatedAt'
    emailMessageQuery.equalTo 'user', Parse.User.current()

    # query Parse for the messages
    emailMessageQuery.find
      success: (data) =>
        # create an array for the messages
        messages = Ember.makeArray()

        user = this.getCurrentUser()

        # loop through all the messages and load them into the array of Neptune.EmailMessage objects
        for i in [0...data.length]
          parseMessage = data[i]

          message = Neptune.EmailMessage.create({
            objectId: parseMessage.id
            fromUser: user
            toEmail: parseMessage.attributes.toEmail
            subject: parseMessage.attributes.subject
            body: parseMessage.attributes.body
          })

          messages.pushObject message

        # return the array of messages
        callback(messages, null)
      error: (error) =>
        callback(null, this.getError(error.code, error.message, 'Neptune.parseDataSource-getEmailMessages'))

  # getSmsMessages - return sms messages sent out by the current user
  #   parameters
  #     callback - callback function to return the data and/or error
  #   returns
  #     success - Ember.Array of Neptune.Message objects, null
  #     failure - null, Neptune.Error object
  getSmsMessages: (callback) ->
    # setup a Parse query to search for all messages for the user passed in ordered by update date
    SmsMessage = Parse.Object.extend('SmsMessage')
    smsMessageQuery = new Parse.Query(SmsMessage)
    smsMessageQuery.descending 'updatedAt'
    smsMessageQuery.equalTo 'user', Parse.User.current()

    # query Parse for the messages
    smsMessageQuery.find
      success: (data) =>
        # create an array for the messages
        messages = Ember.makeArray()

        user = this.getCurrentUser()

        # loop through all the messages and load them into the array of Neptune.SmsMessage objects
        for i in [0...data.length]
          parseMessage = data[i]

          message = Neptune.SmsMessage.create({
            objectId: parseMessage.id
            fromUser: user
            toPhoneNumber: parseMessage.attributes.toPhoneNumber
            message: parseMessage.attributes.message
          })

          messages.pushObject message

        # return the array of messages
        callback(messages, null)
      error: (error) =>
        callback(null, this.getError(error.code, error.message, 'Neptune.parseDataSource-getSmsMessages'))

  # sendEmailMessage - send an email message out from the system
  #   parameters
  #     message - Neptune.EmailMessage object that containts the information of what message to send
  #     callback - callback function to return the data and/or error
  #   returns
  #     success - the Neptune.EmailMessage object updated with the objectId returned from parse, null
  #     failure - null, Neptune.Error object
  sendEmailMessage: (message, callback) ->
    EmailMessage = Parse.Object.extend('EmailMessage')
    parseMessage = new EmailMessage

    parseMessage.set 'user', Parse.User.current()
    parseMessage.set 'toEmail', message.toEmail
    parseMessage.set 'subject', message.subject
    parseMessage.set 'body', message.body

    parseMessage.save null,
      success: (data) =>
        message.objectId = data.id
        callback(message, null)
      error: (error) =>
        callback(null, this.getError(error.code, error.message, 'Neptune.parseDataSource-sendEmailMessage'))

  # sendSmsMessage - send an sms message out from the system
  #   parameters
  #     message - Neptune.SmsMessage object that containts the information of what message to send
  #     callback - callback function to return the data and/or error
  #   returns
  #     success - the Neptune.SmsMessage object updated with the objectId returned from parse, null
  #     failure - null, Neptune.Error object
  sendSmsMessage: (message, callback) ->
    SmsMessage = Parse.Object.extend('SmsMessage')
    parseMessage = new SmsMessage

    parseMessage.set 'user', Parse.User.current()
    parseMessage.set 'toPhoneNumber', message.toPhoneNumber
    parseMessage.set 'message', message.message

    parseMessage.save null,
      success: (data) =>
        message.objectId = data.id
        callback(message, null)
      error: (error) =>
        callback(null, this.getError(error.code, error.message, 'Neptune.parseDataSource-sendSmsMessage'))

  # getError - logs the error to Parse, and logs it to the console
  #   parameters
  #     code - code of the error
  #     message - message body of the error that occurred
  #     severity - ERROR, WARNING, or INFO
  #     location - location that the error occurred
  #     callback - callback function to return the error model in
  #   returns
  #     failure - Neptune.Error object
  getError: (code, message, severity, location, callback) ->
    # create an ember error to return back
    error = Neptune.Error.create(
              code: code
              severity: severity
              location: location
              message: message
            )

    # log the error to the console if in debug mode
    if Neptune.ApplicationController.debug
      console.log 'Neptune - ' + severity  + ' - Code: ' + code + ' Message: ' + message + ' Location: ' + location

    # save the error to Parse
    ErrorLog = Parse.Object.extend('ErrorLog')
    errorLog = new ErrorLog()
    errorLog.set 'code', code
    errorLog.set 'severity', severity
    errorLog.set 'location', location
    errorLog.set 'message', message
    errorLog.save null

    # return the error
    return error

})
