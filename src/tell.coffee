# Description:
#   Tell Hubot to send a user a message when present in the room
#
# Dependencies:
#   None
#
# Configuration:
#   None
#
# Commands:
#   hubot tell <username> <some message> - tell <username> <some message> next time they are present. Case-Insensitive prefix matching is employed when matching usernames, so "foo" also matches "Foo" and "foooo"
#
# Author:
#   christianchristensen, lorenzhs, xhochy

moment = require 'moment'

module.exports = (robot) ->
  localstorage = {}
  robot.respond /tell ([\w.-]*):? (.*)/i, (msg) ->
    datetime = new Date()
    username = msg.match[1]
    room = msg.message.user.room
    tellmessage = msg.message.user.name + " @ " + datetime.toLocaleString() + " said: " + msg.match[2] + "\r\n"
    if not localstorage[room]?
      localstorage[room] = {}
    if localstorage[room][username]?
      localstorage[room][username] += tellmessage
    else
      localstorage[room][username] = tellmessage
    msg.reply "You got it."
    return
 
  # When a user enters, check if someone left them a message
  robot.enter (msg) ->
    username = msg.message.user.name
    room = msg.message.user.room
    if localstorage[room]?
      for recipient, message of localstorage[room]
        # Check if the recipient matches username
        if username.match(new RegExp "^"+recipient, "i")
          messages = localstorage[room][recipient].split('\r\n')
          for message in messages
            parts   = /(.*)\s@\s(.*)\ssaid:\s(.*)/.exec(message)
            if parts
              sender  = parts[1]
              timeago = moment(Date.parse(parts[2])).fromNow()
              tellmsg = parts[3]
              if tellmsg.indexOf('to ') is 0
                tellmsg = tellmsg.replace(/^to\s/i, '')
              msg.send "#{username}, #{sender} left you a message #{timeago}: #{tellmsg}"
          delete localstorage[room][recipient]
