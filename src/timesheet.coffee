# Description:
#   Manage your timesheet
#
# Dependencies:
#   "moment": "x"
#
# Configuration:
#   None
#
# Commands:
#   hubot what (work orders|wos) do I have - List all work orders assigned to you
#   hubot ts show - Show this weeks timesheet
#   hubot ts show week of MM/DD/YY - Show timesheet for the week containing the provided date
#   hubot ts add (today|yesterday|MM/DD/YY) (HH:MM AM|PM) to (HH:MM AM|PM) for (CLIENT) on (WO #)
#
# Author:
#   pschoenf

moment    = require 'moment'
Mainframe = require './mainframe'

module.exports = (robot) ->
  mainframe = new Mainframe(robot)
  timesheet = new Timesheet(robot, mainframe)

  robot.respond /what (?:work orders|wos) do I have/i, (msg) ->
    msg.reply "I'll send you the list."
    user = user: { name: msg.message.user.name }
    timesheet.getWorkOrders msg.message.user.name, (wos) ->
      if wos and wos.length
        wos.forEach (wo) ->
          robot.send user, "#{wo.client}: #{wo.id} - #{wo.name} with #{wo.estimatedHours - wo.actualHours} hours left out of #{wo.estimatedHours}"
      else
        robot.send user, "You have no work orders assigned to you."


class Timesheet
  constructor: (@robot, @mainframe) ->

  getWorkOrders: (username, callback) =>
    @mainframe.getWorkOrders username, (wos) ->
      callback (wos or [])

  #addEntry: (week, day, start, end, client, project, note) =>
