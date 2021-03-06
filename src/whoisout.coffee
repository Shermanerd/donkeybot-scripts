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
#   hubot (who is|who's) out
#   hubot (who is|who's) out (on vacation|sick)
#   hubot (who is|who's) (working from home|wfh)
#   hubot (who is|who's) (late for work|late|lfw)
#   hubot (who is|who's) leaving early
#   hubot (who is|who's) offsite
#
# Notes:
#
# Author:
#  pschoenf

moment    = require 'moment'
_         = require 'underscore'
Mainframe = require './mainframe.coffee'

class WhoIsOut
  constructor: (@robot, @mainframe, @cache = {}) ->

  directMessage: (username, message) =>
    @robot.send { user: { name: username} }, message

  getNoticeBoardEntries: (for_date, callback) =>
    # Cache requests to speed up replies and reduce load on Mainframe
    key = moment(for_date or new Date()).format('MM/DD/YYYY')
    if @cache[key]
      callback @cache[key]
    else
      @mainframe.getNoticeBoardEntries key, (entries) =>
        # Only cache if results were found
        if entries and entries.length
          @cache[key] = entries
        callback @cache[key] or []

  showNoticeBoard: (username, notices) =>
    if notices and notices.length
      special = notices.filter (n) -> n.special is true
      normal  = notices.filter (n) -> n.special is false
      # If there are nothing but special notices
      if special.length is notices.length
        @directMessage username, "There is nobody out, but there are #{special.length} other notices:"
        special.forEach (s) => @directMessage username, s.reason
      else
        normal.forEach (n) => @directMessage username, "#{n.employee}, #{n.reason}"
        if special.length
          @directMessage username, "There are also #{special.length} other notices:"
          special.forEach (s) => @directMessage username, s.reason
    else
      @directMessage username, "There are no notices for that query."

module.exports = (robot)->
  select_date = moment()
  mainframe   = new Mainframe(robot)
  plugin      = new WhoIsOut(robot, mainframe)

  robot.respond /(?:who's|who is) (out on vacation|on vacation|out sick|sick|offsite|late for work|lfw|working from home|wfh|leaving early|out)$/i, (msg) ->
    msg.reply "I'll send you the list."
    absence_type = msg.match[1]
    plugin.getNoticeBoardEntries select_date, (entries) ->
      filter = 'all'
      switch absence_type
        when 'out on vacation'    then filter = 'vacation'
        when 'on vacation'        then filter = 'vacation'
        when 'out sick'           then filter = 'sick'
        when 'sick'               then filter = 'sick'
        when 'offsite'            then filter = 'offsite'
        when 'late for work'      then filter = 'late'
        when 'lfw'                then filter = 'late'
        when 'working from home'  then filter = 'wfh'
        when 'wfh'                then filter = 'wfh'
        when 'leaving early'      then filter = 'early'
        else                      filter = 'all'
      filtered = if filter is 'all' then entries else _.filter(entries, (entry) -> entry.type is filter)
      plugin.showNoticeBoard msg.message.user.name, filtered
