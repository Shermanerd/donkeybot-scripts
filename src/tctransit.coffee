# Description:
#   Allows users to check MetroTransit times in the TwinCities
#   metrotransit.herokuapp.com
#
# Dependencies:
#   none
# 
# Configuration:
#   none
#
# Commands:
#   hubot list routes matching <query>
#   hubot list <north|south|east|west>bound stops for <route #>
#   hubot when is the next <route #> going <north/south/east/west> from <4 letter stop code>
#
# Author:
#   pyro2927

module.exports = (robot) ->
  api = new TransitAPI(robot)

  robot.respond /list routes matching (.*)/i, (msg) ->
    query = (msg.match[1] or "").toLowerCase()
    # Collect matching routes
    matching = []
    for route, name of api.routes
      if route.toLowerCase().indexOf(query) > -1 or name.toLowerCase().indexOf(query) > -1
        matching.push { route: route, name: name }
    # Send matches back to user
    if matching.length
      for match in matching
        robot.send { user: { name: msg.message.user.name } }, "#{match.route} - #{match.name}"
    else
      robot.send { user: { name: msg.message.user.name } }, "No routes matched."


  robot.respond /list (north|south|east|west)bound stops for (\d{1,3}|888x)/i, (msg) ->
    msg.reply "One sec #{msg.message.user.name}, let me look that up."

    direction = msg.match[1]
    route     = msg.match[2]
    dir       = api.get_direction_id direction.toLowerCase()

    api.get_stops route, dir, (results) ->
      if results
        if results.length > 25
          robot.send { user: { name: msg.message.user.name } }, "There are more than 25 stops. Only showing first 25."
        for stop in results.slice(0, 25)
          robot.send { user: { name: msg.message.user.name } }, "#{stop.key} - #{stop.name}"
      else
        robot.send { user: { name: msg.message.user.name } }, "No stops found."

  robot.respond /when is the next (\d{1,3}|888x) going (north|south|east|west) from ([\w\d]{4})/i, (msg) ->
    msg.reply "One sec #{msg.message.user.name}, let me look that up."

    route     = msg.match[1]
    direction = msg.match[2]
    stop      = msg.match[3]
    dir       = api.get_direction_id direction.toLowerCase()

    api.fetch_next_stop route, dir, stop, (time) ->
      if time
        msg.send "The next #{route} at #{stop} is #{time}"
      else
        msg.send "No stops coming up."
    

class TransitAPI
  constructor: (robot) ->
    @routes = []
    @robot = robot
    @robot.http('http://metrotransit.herokuapp.com/routes')
      .get() (err, res, body) =>
        @routes = JSON.parse(body)

  # Get direction number for API
  get_direction_id: (direction) ->
    dir = -1
    switch direction.toLowerCase()
      when 'north' then dir = 4
      when 'south' then dir = 1
      when 'east'  then dir = 2
      when 'west'  then dir = 3
      else dir = 4
    return dir

  get_route: (name) =>
    for route, title of @routes
      if title.toLowerCase().indexOf(name.toLowerCase()) > -1
        return { id: route, title: title }
    return null

  get_stops: (route, dir, callback) =>
    @robot.http("http://metrotransit.herokuapp.com/stops?route=#{route}&direction=#{dir}")
      .get() (err, res, body) =>
        if err
          callback(null)
        else
          stops = JSON.parse(body)
          callback(stops)

  fetch_next_stop: (route, dir, stopCode, callback) =>
    @robot.http("http://metrotransit.herokuapp.com/nextTrip?route=#{route}&direction=#{dir}&stop=#{stopCode}")
      .get() (err, res, body) =>
        if err or res.statusCode is 500
          callback null
          return
        else
          stops = JSON.parse(body)
          unless stops.length
            callback null
            return
          time = stops[0].time
          if time.match(/Min$/)
            time = "in " + time
          else if time.match(/:/)
            time = "at " + time
          callback time
