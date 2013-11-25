# Description:
#   Find out what's on Nom today
#
# Dependencies:
#   None
#
# Configuration:
#   None
#
# Commands:
#   hubot nom for (9555|9401|300|208)
#   hubot what's for lunch in (9555|9401|300|208)

Mainframe = require './mainframe'

module.exports = (robot) ->
  mainframe = new Mainframe(robot)
  robot.respond /nom for (\d{3,4})\??/i, (msg) ->
    office = msg.match[1]
    mainframe.getNomSchedule office, (schedule) ->
      msg.reply schedule

  robot.respond /what's for lunch in (\d{3,4})\??/i, (msg) ->
    office = msg.match[1]
    mainframe.getNomSchedule office, (schedule) ->
      msg.reply schedule