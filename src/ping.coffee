# Description:
#   Utility commands surrounding Hubot uptime.
#
# Commands:
#   hubot ping - Reply with pong
#   hubot echo <text> - Reply back with <text>
#   hubot time - Reply with current time
#   hubot die - End hubot process

module.exports = (robot) ->
  robot.respond /PING$/i, (msg) ->
    msg.send "PONG"

  robot.respond /ECHO (.*)$/i, (msg) ->
    msg.send msg.match[1]

  robot.respond /TIME$/i, (msg) ->
    msg.send "Server time is: #{new Date()}"

  robot.respond /DIE$/i, (msg) ->
    isAdmin = (process.env.HUBOT_AUTH_ADMIN or "").toLowerCase() is msg.message.user.name.toLowerCase()
    if isAdmin
        msg.send "Goodbye, cruel world."
        process.exit 0
    else
        msg.send "http://t.qkme.me/3uypa6.jpg"

