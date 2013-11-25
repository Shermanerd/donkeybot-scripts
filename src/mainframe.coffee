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

class WorkOrder
  constructor: () ->
    @id             = 'ADMIN'
    @name           = 'ADMIN'
    @client         = 'SIERRA'
    @project        = 'ADMIN'
    @estimatedHours = 0.00
    @actualHours    = 0.00

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
        unless body and !err and res.statusCode isnt 500
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
              if parts
                result.special  = false
                result.type     = notice_type.toLowerCase()
                result.employee = parts[1]
                result.reason   = parts[2]
              else
                result.special  = true
                result.type     = "None"
                result.employee = "Everyone"
                result.reason   = notice

            results.push result
          # Clean up memory
          window.close()
          # Send results back to caller
          callback results

  getWorkOrders: (username, callback) =>
    @robot.http("https://mainframe.nerdery.com/workman.php?alt_user=#{username}")
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
          $('#assignedworkorders tbody tr').each (i, tr) ->
            $tr           = $(tr)
            wo = new WorkOrder()
            wo.id = $tr.find('td:nth-child(2) a').html()
            wo.name = $tr.find('td:nth-child(8) a').html()
            wo.client = $tr.find('td:nth-child(3) a').html()
            wo.project = $tr.find('td:nth-child(4) a').html()
            # Parse hours actual/estimated
            hours_format = /^(.*) \/ (.*)$/i
            parts = hours_format.exec $tr.find('td:nth-child(5)').html()
            wo.estimatedHours = parts[2].trim()
            wo.actualHours = if parts[1].trim() then parts[1].trim() else 0.00

            results.push wo
          # Clean up memory
          window.close()
          # Send results back to caller
          callback results

  postTimeEntry: (entry, callback) =>
    # POST data format
    data = {
      'id': 'NEW',
      'ts_user': entry.user,
      'self_user': entry.user,
      'week_ending': entry.weekOf,
      'current_week': entry.weekOf,
      'day': entry.day,
      'start_time': entry.startTime,
      'end_time': entry.endTime,
      'client': entry.client,
      'project': entry.wo,
      'notes': entry.note
    }

    @robot.http("https://mainframe.nerdery.com/timesheet.php")
      .headers(@getAuthHeader())
      .query(data)
      .post() (err, res, body) =>
        # Return false if request fails
        if err or res.statusCode is 500
          callback false, "Sorry, server error."
        else
          # Successful POST
          if res.statusCode is 302
            callback true
          # POST failed for another reason, and we've been redirected
          else
            jsdom.env html: body, src: [jquery], done: (errs, window) ->
              unless window
                callback false, "I wasn't able to load your timesheet :("
                return

              errors = window.$('#TSEntryForm').prev('.error')
              # Clean up memory
              window.close();
              if errors and errors.length
                error = errors.text()?.replace(/\s{2,}/, ' ').trim();
                callback false, error
              else
                callback true

  getNomSchedule: (office, callback) =>
    schedule_date = moment()
    office_location = 1
    switch office.toLowerCase()
      when '9555' then office_location = 1
      when '9401' then office_location = 2
      when '300'  then office_location = 3
      when '208'  then office_location = 4
      else office_location = 1 # Default to 9555

    @robot.http("https://mainframe.nerdery.com/nom/ordering/schedule/date/#{schedule_date.format('YYYY-MM-DD')}/officeLocation/#{office_location}")
      .headers(@getAuthHeader())
      .get() (err, res, body) =>
        if err or res.statusCode is 500
          callback "Unable to get today's Nom schedule"
        else
          jsdom.env html: body, src: [jquery], done: (errs, window) ->
            unless window
              callback "Unable to get today's Nom schedule"
              return

            $ = window.$
            results = []
            # First check to see that a schedule exists
            if $('.schedule .notice').length
              callback $('.schedule .notice').text()
              window.close()
            else
              # Scrape page for weekly schedule
              $('.weeklySchedule').find('tbody tr:first-child td').each (i, el) ->
                  $el  = $(el)
                  day  = $('.weeklySchedule').find("thead th:nth-child(#{i + 1})").text()
                  temp = []
                  $el.find('ul li').each (j, el2) ->
                      temp.push $(el2).text()
                  date = moment(day, 'dd, MMM D')
                  results.push date: date, selections: temp.join(', ')
              # Clean up memory
              window.close()
              # Find today's schedule
              schedule = _.find results, (item) -> return item.date.isSame(schedule_date, 'day')
              if schedule
                callback schedule.selections
              else
                callback "There is no schedule for today."

module.exports = Mainframe

