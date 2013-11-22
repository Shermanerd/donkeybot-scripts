# Description:
#   Tell Hubot what you're working on so he can give out status updates when asked
#
# Dependencies:
#   None
#
# Configuration:
#   None
#
# Commands:
#   hubot i am working on <anything> - Set what you're working on
#   hubot what is everyone working on? - Find out what everyone is working on
#   hubot who needs work - Find out who all needs work
#   hubot who needs <discipline> work - Find out who all needs work within a discipline
#   hubot who needs work in the next <n> <days|weeks|months> - Who needs work within a time range
#   hubot who needs <discipline> work in the next <n> <days|weeks|months>
#
# Author:
#   pschoenf

_      = require 'underscore'
moment = require 'moment'

module.exports = (robot) ->

  getAuthHeader = ->
    username = process.env.HUBOT_MAINFRAME_USER
    password = process.env.HUBOT_MAINFRAME_PASSWORD
    return Authorization: "Basic #{new Buffer("#{username}:#{password}").toString("base64")}", Accept: "application/json", Cookie: 'PHPSESSID=1'

  fetch_needs_work = (callback) =>
    robot.http('https://mainframe.nerdery.com/needs-work/list/format/json')
      .headers(getAuthHeader())
      .get() (err, res, body) =>
        if err or res.statusCode is 500
          callback([])
          return

        data = JSON.parse(body)
        results = _.map data, (entry) ->
          employee_name = entry.consultant.name
          work_by       = entry.needswork_by
          disciplines   = []
          disciplines.push(entry.consultant_discipline.name) if entry.consultant_discipline.id
          disciplines.push(entry.consultant_secondary_discipline.name) if entry.consultant_secondary_discipline.id
          disciplines.push(entry.consultant_tertiary_discipline.name) if entry.consultant_tertiary_discipline.id
          return {
            'employee': employee_name,
            'needs_work_by': moment(Date.parse(work_by)),
            'disciplines': disciplines
          }

        callback(results)

  robot.respond /(who needs|who is in need of) (.+\s?)?work( in the next (\d+) (days|weeks|months))?\??/i, (msg) =>
    msg.reply "Let me look!"

    user            = msg.message.user.name
    work_type       = msg.match[2].trim() if msg.match[2]
    range_num       = 1
    range_scale     = 'weeks'
    has_specificity = !!msg.match[3]
    if has_specificity
      range_num   = parseInt msg.match[4]
      range_scale = msg.match[5]

    fetch_needs_work (results) ->
      needs_work_before = moment().add(range_scale, range_num)
      filtered = results.filter((r) -> r.needs_work_by.isBefore(needs_work_before) or r.needs_work_by.isSame(needs_work_before))
      filtered = if work_type then filtered.filter((r) -> _.any(r.disciplines, (d) -> d.toLowerCase() is work_type)) else filtered
      if filtered.length
        for entry in filtered
          needs_work_by = if moment().isAfter(entry.needs_work_by) then entry.needs_work_by.from() else entry.needs_work_by.fromNow()
          if work_type
            robot.send { user: { name: user } }, "#{entry.employee}: #{needs_work_by}"
          else
            robot.send { user: { name: user } }, "#{entry.employee}: #{needs_work_by} in #{entry.disciplines.join(', ')}"
        msg.reply "I sent you a list of the users needing work."
      else
        if work_type
          msg.reply "There aren't any users that need #{work_type} work in the next #{range_num} #{range_scale}."
        else
          msg.reply "There aren't any users that need work in the next #{range_num} #{range_scale}."

  robot.respond /(what\'s|what is|whats) @?([\w .\-]+) working on(\?)?$/i, (msg) ->
    name = msg.match[2].trim()

    if name is "you"
      msg.send "I dunno, robot things I guess."
    else if name.toLowerCase() is robot.name.toLowerCase()
      msg.send "World domination!"
    else if name.match(/(everybody|everyone)/i)
      messageText = '';
      users = robot.brain.users()
      for k, u of users
          if u.workingon
              messageText += "#{u.name} is working on #{u.workingon}\n"
          else
              messageText += ""
      if messageText.trim() is "" then messageText = "Nobody told me a thing."
      msg.send messageText
    else
      users = robot.brain.usersForFuzzyName(name)
      if users.length is 1
        user = users[0]
        user.workingon = user.workingon or [ ]
        if user.workingon.length > 0
          msg.send "#{name} is working on #{user.workingon}."
        else
          msg.send "#{name} is slacking off."
      else if users.length > 1
        msg.send getAmbiguousUserText users
      else
        msg.send "#{name}? Who's that?"

  robot.respond /(i\'m|i am|im) working on (.*)/i, (msg) ->
    name = msg.message.user.name
    user = robot.brain.userForName name

    if typeof user is 'object'
      user.workingon = msg.match[2]
      msg.send "Okay #{user.name}, got it."
    else if typeof user.length > 1
      msg.send "I found #{user.length} people named #{name}"
    else
      msg.send "I have never met #{name}"

