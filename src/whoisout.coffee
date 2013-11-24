## Description
#   Show data from the Notice Board, as well as informal absences
#
# Dependencies:
#   "moment": "x"
#   "underscore": "x"
#   "jsdom": "x"
#
# Configuration:
#
# Commands:
#   hubot I will be out [date]
#   hubot who is offsite
#   hubot who is out (on vacation|sick)
#   hubot who is (working from home|wfh)
#   hubot who is (late for work|late|lfw)
#   hubot who is leaving early
#
# Notes:
#
# Author:
#  pschoenf/Contejious

moment    = require 'moment'
_         = require 'underscore'
mainframe = require 'mainframe'

class WhoIsOut
  constructor (@robot) ->
    # Cache requests to speed up replies and reduce load on Mainframe
    @cache = {}

  getNoticeBoardEntries = (for_date, callback) =>
    key = moment(for_date or new Date()).format('MM/DD/YYYY')
    if @cache[key]
      callback @cache[key]
    else
      mainframe.getNoticeBoardEntries key, (entries) =>
        # Only cache if results were found
        if entries and entries.length
          @cache[key] = entries
        callback @cache[key]

  showNoticeBoard = (notices) =>

module.exports = (robot)->
  plugin = new WhoIsOut(robot)
  select_date = moment().subtract('days', 2)

  robot.brain.on 'loaded', =>
    robot.brain.data.outList = []  unless _(robot.brain.data.outList).isArray()

  robot.respond /(?:who's|who is) (out on vacation|out sick|offsite|late for work|lfw|working from home|wfh|leaving early|out)$/i, (msg) ->
    absence_type = msg.match[1]
    plugin.getNoticeBoardEntries select_date, (entries) ->
      filter = 'all'
      switch absence_type
        when 'out on vacation'    then filter = 'vacation'
        when 'out sick'           then filter = 'sick'
        when 'offsite'            then filter = 'offsite'
        when 'late for work'      then filter = 'late'
        when 'lfw'                then filter = 'late'
        when 'working from home'  then filter = 'wfh'
        when 'wfh'                then filter = 'wfh'
        when 'leaving early'      then filter = 'early'
        else                      then filter = 'all'
      entries = _.filter(entries, (entry) -> entry.type.toLowerCase() is filter) unless filter = 'all'
      plugin.showNoticeBoard entries

  robot.respond /(?:I am|I'm|I will be) out +(.*)/i, (msg)->
    thisDate = parseDate msg.match[1]?.trim()
    if thisDate
      save thisDate, msg.message
      msg.send "ok, #{msg.message.user.name} is out on #{thisDate}"
    else
      msg.send 'unable to save date'

  robot.respond /when is (.*)/i, (msg)->
    msg.send plugin.parseDate msg.match[1]?.trim()

  parseDate = (fuzzyDateString)->
    fuzzyDateString = fuzzyDateString.toLowerCase()
    if fuzzyDateString.split(" ")[0] is "next"
      plusOneWeek = true
      fuzzyDateString = fuzzyDateString.split(" ")[1]
    day = 1000*60*60*24
    week = day*7
    switch fuzzyDateString
      when "tomorrow"
        return new Date((new Date).getTime() + day)
      when "today"
        return new Date()
      when "sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"
        days = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"]
        date = new Date()
        date = new Date(date.getTime() + day) until days[date.getDay()] == fuzzyDateString
        date = new Date(date.getTime() + week) if plusOneWeek
        return date
      else
        if (@thisDate = (moment fuzzyDateString)).isValid()
          return @thisDate.toDate()
        else
          return false

  save = (date, msg)->
    userOutList = robot.brain.data.outList
    userVacation = _(userOutList).find (item)-> item.name is msg.user.name

    if userVacation is undefined
      userOutList.push
        name: msg.user.name
        dates: [date]
    else
      unless _(userVacation.dates).some( (item)-> (moment item).format('M/D/YY') is (moment date).format('M/D/YY'))
        userVacation.dates.push date

  getAbsentees = (targetDate)->
    targetDate = new Date() unless targetDate?
    if _(robot.brain.data.outList).isArray() and (robot.brain.data.outList.length > 0)
      names = []
      _(robot.brain.data.outList).each (item)->
        if(_(item.dates).some( (dt)-> (moment dt).format('M/D/YY') is (moment targetDate).format('M/D/YY')))
          names.push item.name
      if names.length > 0
        names.join '\n'
      else
        return 'Nobody'
    else
      return 'Nobody'
