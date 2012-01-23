#!/usr/bin/env coffee

sendingAddress = process.argv[2]   # first argument  -- e.g. '127.0.0.1'
port = parseInt(process.argv[3])   # second argument -- e.g. 10000
https = process.argv[4] is 'https' # third arg -- 'https' or not

WebSocketServer = require('websocket').server
fs = require('fs')

html = fs.readFileSync('index.html')
httpCallback = (request, response) ->
  response.write(html)
  response.end()

httpServer = if https
  key  = fs.readFileSync('server.key')
  cert = fs.readFileSync('server.crt')
  https = require('https')
  https.createServer {key, cert}, httpCallback
else
  http = require('http')
  http.createServer httpCallback

httpServer.listen(port)

wsServer = new WebSocketServer(httpServer: httpServer, autoAcceptConnections: false)
wsServer.on 'request', (request) ->
  connection = request.accept(null, request.origin)
  console.log "clients: #{wsServer.connections.length}"
  if connection.remoteAddress is sendingAddress
    connection.on 'message', (message) ->
      for c in wsServer.connections
        continue if c is connection                        # don't send back to the sender
        continue unless c.socket.bufferSize is 0 or https  # minimal buffering for slow connections (doesn't work with SSL)
        c.sendBytes(message.binaryData)
