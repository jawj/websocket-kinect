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
log = (s) -> console.log "#{new Date()} - clients: #{wsServer.connections.length} - #{s}"

wsServer.on 'request', (request) ->
  if wsServer.connections.length > 3000
    log "rejected connection"
    request.reject()
    return
  connection = request.accept(null, request.origin)
  log "connected: #{connection.remoteAddress}"
  if connection.remoteAddress is sendingAddress
    connection.on 'message', (message) ->
      for c in wsServer.connections
        continue if c is connection                            # don't send back to the sender
        continue unless https or c.socket.bufferSize < 100000  # minimal buffering for slow connections (doesn't work with SSL)
        c.sendBytes(message.binaryData)
  connection.on 'close', (reasonCode, description) ->
    log "disconnected: #{connection.remoteAddress}"
