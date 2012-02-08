#!/usr/bin/env coffee

redirectUrl = process.argv[2]
listenPort  = parseInt(process.argv[3])

httpServer = require('http').createServer (req, res) ->
  res.writeHead(302, {Location: redirectUrl})
  res.end()
  console.log("#{new Date()} - redirected")

httpServer.listen(listenPort)
