#!/usr/bin/env coffee

# changes for Nodester:
# - hardcode the 3 command-line parameters immediately below
# - uploaded precompiled as server.js
# - read index.html.gz from /app

# changes for cloudno.de: as Nodester, except index.html.gz can be read from local dir
util = require('util')
sendingAddress = process.argv[2]   # first argument  -- e.g. '127.0.0.1'
port = parseInt(process.argv[3])   # second argument -- e.g. 10000
https = process.argv[4] is 'https' # third arg -- 'https' or not

WebSocketServer = require('websocket').server
fs = require('fs')

page = fs.readFileSync('index.html.gz')
httpCallback = (request, response) ->
  m = request.method
  if m in ['GET', 'HEAD']
    response.setHeader('Content-Encoding', 'gzip')
    response.write(page) if m is 'GET'
  else
    response.writeHead(501, 'Not Implemented')
  response.end()

httpServer = if https
  key  = fs.readFileSync('server.key')
  cert = fs.readFileSync('server.crt')
  require('https').createServer {key, cert}, httpCallback
else
  require('http').createServer httpCallback

httpServer.listen(port)

wsServer = new WebSocketServer(httpServer: httpServer, autoAcceptConnections: false)
log = (s) -> console.log "#{new Date()} - clients: #{wsServer.connections.length} - #{s}"

wsServer.on 'request', (request) ->
  if wsServer.connections.length > 100  # max connections
    log "rejected connection"
    request.reject()
    return
  connection = request.accept(null, request.origin)
  log "connected:    #{connection.remoteAddress}\x07"
  # Use this to figure out what you need to enter for your sendingAddress argument
  # log (console.log(util.inspect(connection, {showHidden: false, depth: null})))
  if connection.remoteAddress is sendingAddress
    connection.on 'message', (message) ->
      for c in wsServer.connections
        # don't send back to the sender and only allow 256KB of buffering (unless on https, when bufferSize isn't available)
        c.sendBytes(message.binaryData) if c isnt connection and (https or c.socket.bufferSize < 262144)
  connection.on 'close', (reasonCode, description) ->
    log "disconnected: #{connection.remoteAddress}"
