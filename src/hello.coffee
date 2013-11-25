# Description:
#   Hubot, be polite and say hello.
#
# Dependencies:
#   None
#
# Configuration:
#   None
#
# Commands:
#   yo|sup|what's up|hey|hi|hello|good day - make hubot say hello to you back
#   good morning - makes hubot say good morning to you back

_ = require 'underscore'

hellos = [
    "Well hello there, %",
    "Hey %, Hello!",
    "Marnin', %",
    "Good day, %",
    "Good 'aye!, %",
]
mornings = [
    "Good morning, %",
    "Good morning to you too, %",
    "Good day, %",
    "Good 'aye!, %"
]

module.exports = (robot) ->
  robot.hear /(yo|sup|what's up|hey|hi|hello|good( [d'])?ay(e)?)/i, (msg) ->
    expected = [ "#{robot.name} #{msg.match[1]}", "#{msg.match[1]} #{robot.name}" ]
    matches = _.any(expected, (phrase) -> msg.message.text.toLowerCase().indexOf(phrase.toLowerCase()) > -1)
    unless matches
      hello = msg.random hellos
      msg.send hello.replace "%", msg.message.user.name

  robot.hear /(^(good )?m(a|o)rnin(g)?)/i, (msg) ->
    hello = msg.random mornings
    msg.send hello.replace "%", msg.message.user.name
