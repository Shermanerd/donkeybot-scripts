# Description:
#   Track arbitrary karma
#
# Dependencies:
#   None
#
# Configuration:
#   KARMA_ALLOW_SELF
#
# Commands:
#   <thing>++ - give thing some karma
#   <thing>++ <comment> - give thing some karma along with an explanation
#   <thing>-- - take away some of thing's karma
#   <thing>-- <comment> - take away some of thing's karma with an explanation
#   hubot karma <thing> - check thing's karma (if <thing> is omitted, show the top 5)
#   hubot karma explain <thing> - show the comments for the last 3 positive and negative votes
#   hubot karma empty <thing> - empty a thing's karma
#   hubot karma best - show the top 5
#   hubot karma worst - show the bottom 5
#
# Author:
#   stuartf/pschoenf

class Karma

  constructor: (@robot) ->
    @cache = {}

    @increment_responses = [
      "+1!", "gained a level!", "is on the rise!", "leveled up!"
    ]

    @decrement_responses = [
      "took a hit! Ouch.", "took a dive.", "lost a life.", "lost a level."
    ]

    @robot.brain.on 'loaded', =>
      if @robot.brain.data.karma
        @cache = @robot.brain.data.karma

  kill: (thing) ->
    delete @cache[thing]
    @robot.brain.data.karma = @cache

  increment: (thing, comment = "No comment provided.") ->
    unless @cache[thing]
      @cache[thing] = { karma: 0, comments: [] }

    @cache[thing].karma += 1
    @cache[thing].comments.push { vote: 1, comment: comment }

    # Trim comments down to the last 3 negative and positive
    negative_comments = (c for c in @cache[thing].comments when c.vote < 0)
    positive_comments = (c for c in @cache[thing].comments when c.vote > 0)
    @cache[thing].comments = positive_comments.slice(-3).concat negative_comments.slice(-3)

    @robot.brain.data.karma = @cache

  decrement: (thing, comment = "No comment provided.") ->
    unless @cache[thing]
      @cache[thing] = { karma: 0, comments: [] }

    @cache[thing].karma -= 1
    @cache[thing].comments.push { vote: -1, comment: comment }

    # Trim comments down to the last 3 negative and positive
    negative_comments = (c for c in @cache[thing].comments when c.vote < 0)
    positive_comments = (c for c in @cache[thing].comments when c.vote > 0)
    @cache[thing].comments = positive_comments.slice(-3).concat negative_comments.slice(-3)

    @robot.brain.data.karma = @cache

  incrementResponse: ->
     @increment_responses[Math.floor(Math.random() * @increment_responses.length)]

  decrementResponse: ->
     @decrement_responses[Math.floor(Math.random() * @decrement_responses.length)]

  selfDeniedResponses: (name) ->
    @self_denied_responses = [
      "Hey everyone! #{name} is a narcissist!",
      "I might just allow that next time, but no.",
      "I can't do that #{name}."
    ]

  get: (thing) ->
    k = if @cache[thing] then @cache[thing] else { karma: 0, comments: [] }
    return k

  sort: ->
    s = []
    for key, val of @cache
      s.push({ name: key, details: val })
    s.sort (a, b) -> b.details.karma - a.details.karma

  top: (n = 5) ->
    sorted = @sort()
    console.log(sorted)
    sorted.slice(0, n)

  bottom: (n = 5) ->
    sorted = @sort()
    sorted.slice(-n).reverse()

module.exports = (robot) ->
  karma = new Karma robot
  allow_self = process.env.KARMA_ALLOW_SELF or "true"

  robot.hear /(\S+[^+:\s])[: ]*\+\+\s?(.*)$/, (msg) ->
    subject = msg.match[1].toLowerCase()
    comment = msg.match[2]
    if allow_self is true or msg.message.user.name.toLowerCase() != subject
      karma.increment subject, comment
      item = karma.get(subject)
      msg.send "#{subject} #{karma.incrementResponse()} (Karma: #{item.karma})"
    else
      msg.send msg.random karma.selfDeniedResponses(msg.message.user.name)

  robot.hear /(\S+[^-:\s])[: ]*--\s?(.*)$/, (msg) ->
    subject = msg.match[1].toLowerCase()
    comment = msg.match[2]
    if allow_self is true or msg.message.user.name.toLowerCase() != subject
      karma.decrement subject, comment
      item = karma.get(subject)
      msg.send "#{subject} #{karma.decrementResponse()} (Karma: #{item.karma})"
    else
      msg.send msg.random karma.selfDeniedResponses(msg.message.user.name)

  robot.respond /karma empty ?(\S+[^-\s])$/i, (msg) ->
    subject = msg.match[1].toLowerCase()
    isAdmin = (process.env.HUBOT_AUTH_ADMIN or "").toLowerCase() is subject
    if isAdmin or (allow_self is true or msg.message.user.name.toLowerCase() != subject)
      karma.kill subject
      msg.send "#{subject} has had its karma scattered to the winds."
    else
      msg.send msg.random karma.selfDeniedResponses(msg.message.user.name)

  robot.respond /karma( best)?$/i, (msg) ->
    verbiage = ["The Best"]
    for item, rank in karma.top()
      verbiage.push "#{rank + 1}. #{item.name} - #{item.details.karma}"
    msg.send verbiage.join("\n")

  robot.respond /karma worst$/i, (msg) ->
    verbiage = ["The Worst"]
    for item, rank in karma.bottom()
      verbiage.push "#{rank + 1}. #{item.name} - #{item.details.karma}"
    msg.send verbiage.join("\n")

  robot.respond /karma (\S+[^-\s])$/i, (msg) ->
    match = msg.match[1].toLowerCase()
    if match != "best" && match != "worst"
      item = karma.get match
      msg.send "\"#{match}\" has #{item.karma} karma."

  robot.respond /karma explain (\S+[^-\s])$/i, (msg) ->
    match = msg.match[1].toLowerCase()
    thing = karma.get match
    if thing.comments.length
      positive = (c for c in thing.comments when c.vote > 0)
      if positive.length
        msg.send "Last 3 positive votes for #{match}:"
        for comment, rank in positive
          msg.send "   \"#{comment.comment}\""
      else
        msg.send "Nobody had anything good to say about #{match}"

      negative = (c for c in thing.comments when c.vote < 0)
      if negative.length
        msg.send "Last 3 negative votes for #{match}"
        for comment, rank in negative
          msg.send "    \"#{comment.comment}\""
      else
        msg.send "Nobody had anything negative to say about #{match}"
    else
      msg.send "#{match} has no karma."

