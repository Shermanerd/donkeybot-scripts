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
#   hubot ts add <note> from (HH:MM AM|PM) to (HH:MM AM|PM) (today|yesterday|day of week) for <client> on <wo>
#
# Author:
#   pschoenf

moment    = require 'moment'
require '../lib/moment.isocalendar.js'
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

  robot.respond /ts add (.+) from (\d{1,2}:\d{2} (?:am|pm)) to (\d{1,2}:\d{2} (?:am|pm)) (today|yesterday|monday|tuesday|wednesday|thursday|friday|saturday|sunday) for (.+) on (.+)/i, (msg) ->
    user = user: { name: msg.message.user.name }
    # Parse date syntax
    date = msg.match[4]
    switch date
      when 'today'     then date = moment()
      when 'yesterday' then date = moment().subtract('days', 1)
      else date = moment().add('days', getDiff date)

    # Create time entry
    entry = new Entry()
    entry.user      = msg.message.user.name
    entry.startTime = msg.match[2]
    entry.endTime   = msg.match[3]
    entry.client    = msg.match[5]
    entry.wo        = msg.match[6]
    entry.note      = msg.match[1]
    entry.setDate date

    timesheet.addEntry entry, (success, error) ->
      if success
        msg.reply "Entry added!"
      else
        msg.reply error

  # Determine the relative difference between today and another day this week, using ISO calendar values
  # Ex. If today is Sunday (7), then the difference between today and last Monday (1) is 6
  getDiff = (dayname) ->
    day = moment().isoWeekday()
    diff = 0
    switch dayname
      when 'monday'    then diff = 1 - day
      when 'tuesday'   then diff = 2 - day
      when 'wednesday' then diff = 3 - day
      when 'thursday'  then diff = 4 - day
      when 'friday'    then diff = 5 - day
      # For Saturday and SUnday, always look back to the previous weekend
      when 'saturday'  then diff = (6 - (7 + day))
      when 'sunday'    then diff = (7 - (7 + day))
      else diff = 0
    return diff

class Entry
  constructor: () ->
    @user = ''
    @setDate moment()
    @startTime = '9:30 AM'
    @endTime = '10:30 AM'
    @client = 'SIERRA'
    @wo = 'ADMIN'
    @note = 'No note provided.'

  setDate: (date) =>
    @weekOf = @getWeekEndDate date
    @day = date.format('dddd')

  getWeekEndDate: (date) =>
    day = date.isoWeekday()
    # If this is a Saturday or Sunday, look forward a week
    if day > 5
      return moment(date).add('days', 5 + (7 - day)).format('MM/DD/YY')
    else
      return moment(date).add('days', 5 - day).format('MM/DD/YY')

class Timesheet
  constructor: (@robot, @mainframe) ->

  getWorkOrders: (username, callback) =>
    @mainframe.getWorkOrders username, (wos) ->
      callback (wos or [])

  addEntry: (entry, callback) =>
    @mainframe.postTimeEntry entry, callback
