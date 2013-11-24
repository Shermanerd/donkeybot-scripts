# Description:
#   Provides Mainframe data access methods for use by other scripts
#
# Dependencies:
#   "moment": "x"
#   "underscore": "x"
#   "jsdom": "x"
#
# Configuration:
#   None
#
# Commands:
#   None
#
# Author:
#   pschoenf

moment = require 'moment'
_      = require 'underscore'
jsdom  = require 'jsdom'
fs     = require 'fs'
Path   = require 'path'
jquery = fs.readFileSync (Path.resolve __dirname, '../lib/jquery.js'), 'utf-8'

class NeedsWorkEntry
  constructor: () ->
    @employee      = 'Nobody'
    @needs_work_by = moment()
    @disciplines   = []

class NoticeBoardEntry
  constructor: () ->
    @type     = 'None'
    @employee = 'Nobody'
    @reason   = 'Unknown'

class Mainframe
  constructor: (@robot) ->
    @username = process.env.HUBOT_MAINFRAME_USER ||= ''
    @password = process.env.HUBOT_MAINFRAME_PASSWORD ||= ''

  getAuthHeader: =>
    return Authorization: "Basic #{new Buffer("#{@username}:#{@password}").toString("base64")}", Accept: "application/json,text/plain,text/html", Cookie: 'PHPSESSID=1'

  getNeedsWorkEntries: (callback) =>
    @robot.http('https://mainframe.nerdery.com/needs-work/list/format/json')
      .headers(@getAuthHeader())
      .get() (err, res, body) =>
        # Return sane default if request fails for any reason
        if err or res.statusCode is 500
          callback []
          return

        data = JSON.parse(body)
        results = _.map data, (entry) ->
          result = new NeedsWorkEntry()
          result.employee = entry.consultant.name
          result.needs_work_by = moment(Date.parse(entry.needswork_by))
          result.disciplines.push(entry.consultant_discipline.name)           if entry.consultant_discipline.id
          result.disciplines.push(entry.consultant_secondary_discipline.name) if entry.consultant_secondary_discipline.id
          result.disciplines.push(entry.consultant_tertiary_discipline.name)  if entry.consultant_tertiary_discipline.id
          return result

        callback(results)

  getNoticeBoardEntries: (select_date, callback) =>
    select_date = select_date || moment(new Date()).format('MM/DD/YYYY')
    @robot.http("https://mainframe.nerdery.com/schedcal.php?sel_date=#{select_date}")
      .headers(@getAuthHeader())
      .get() (err, res, body) =>
        # Return sane default if request fails for any reason
        if err or res.statusCode is 500
          callback []
          return

        # Load result HTML in jsdom for scraping
        jsdom.env html: body, src: [jquery], done: (errors, window) ->
          # Exit early if loading fails
          unless window
            callback []
            return

          $       = window.$;
          results = []
          $('form[name=schedform] table.data_table > tbody tr').each (i, tr) -> 
            $tr           = $(tr)
            notice        = $tr.find('td:first-child').text()
            notice_type   = $tr.find('td:last-child').text()
            notice_format = /^(\w+\s.+)\s\((.*)\)$/i
            result        = new NoticeBoardEntry()
            # Check if this is a special event
            if notice.toLowerCase().indexOf('happy') is 0
              special_format  = /^Happy (Birthday|\d{1,2}(?:st|nd|rd|th) .+)\s?(on Saturday|on Sunday)? to (.*)!/i
              parts           = special_format.exec notice
              result.special  = true
              result.type     = parts[1].toLowerCase()
              result.employee = parts[3]
              date_of         = if parts[2] then parts[2] else 'Today'
              result.reason   = if date_of is 'Today' then "Today is #{result.employee}'s #{result.type}" else "#{date_of.substring(3)} is #{result.employee}'s #{result.type}"
            # Otherwise this is a vacation|sick day|late for work scenario
            else
              parts           = notice_format.exec notice
              result.special  = false
              result.type     = notice_type.toLowerCase()
              result.employee = parts[1]
              result.reason   = parts[2]

            results.push result
          # Clean up memory
          window.close()
          # Send results back to caller
          callback results

module.exports = Mainframe

