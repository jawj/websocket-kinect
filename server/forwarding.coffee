#!/usr/bin/env coffee

sendingAddress = process.argv[2]  # first argument -- e.g. '127.0.0.1'

WebSocketServer = require('websocket').server
http = require('http')

hServer = http.createServer (request, response) ->
  response.writeHead(404)
  response.end()
hServer.listen(10000)

wsServer = new WebSocketServer(httpServer: hServer, autoAcceptConnections: false)
wsServer.on 'request', (request) ->
  connection = request.accept(null, request.origin)
  if connection.remoteAddress is sendingAddress
    connection.on 'message', (message) ->
      for c in wsServer.connections
        c.sendBytes(message.binaryData) unless c is connection
