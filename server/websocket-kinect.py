#!/usr/bin/env python

import sys
from twisted.internet import reactor, threads
from autobahn.websocket import WebSocketServerFactory, WebSocketServerProtocol, listenWS
import freenect
import signal
import numpy
import bz2

class BroadcastServerProtocol(WebSocketServerProtocol):
  
  def onOpen(self):
    self.factory.register(self)
  
  def connectionLost(self, reason):
    WebSocketServerProtocol.connectionLost(self, reason)
    self.factory.unregister(self)

class BroadcastServerFactory(WebSocketServerFactory):
  
  protocol = BroadcastServerProtocol
  
  def __init__(self, url):
    WebSocketServerFactory.__init__(self, url)
    self.clients = []
  
  def register(self, client):
    if not client in self.clients:
      print "registered client: " + client.peerstr
      self.clients.append(client)
  
  def unregister(self, client):
    if client in self.clients:
      print "unregistered client: " + client.peerstr
      self.clients.remove(client)
  
  def broadcast(self, msg, binary = False):
    for c in self.clients:
      c.sendMessage(msg, binary)

class Kinect:
  
  def __init__(self):
    useEvery = 4
    h = 480 / useEvery
    w = 640 / useEvery
    self.useCols, self.useRows = numpy.indices((h, w))
    self.useCols *= useEvery
    self.useRows *= useEvery
  
  def depthCallback(self, dev, depth, timestamp):
    # print "%d min, %d max" % (numpy.min(depth), numpy.max(depth))
    depth = depth[self.useCols, self.useRows]
    numpy.clip(depth, 0, 2 ** 10 - 1, depth)
    depth >>= 2
    # depth = (depth - 200) >> 3
    dataString = depth.astype(numpy.uint8).tostring()
    # reactor.callFromThread(factory.broadcast, dataString, True)
    reactor.callFromThread(factory.broadcast, bz2.compress(dataString), True)
  
  def bodyCallback(self, *args):
    if not self.kinecting: raise freenect.Kill
  
  def run(self):
    self.kinecting = True
    reactor.callInThread(freenect.runloop, depth = self.depthCallback, body = self.bodyCallback, video = None)
  
  def stop(self):
    self.kinecting = False

def signalHandler(signum, frame):
  kinect.stop()
  reactor.stop()

port = sys.argv[1] if len(sys.argv) > 1 else "9000"
url = "ws://localhost:" + port

signal.signal(signal.SIGINT, signalHandler)
print '>>> Broadcasting at %s --- Press Ctrl-C to stop <<<' % url

kinect = Kinect()
kinect.run()
factory = BroadcastServerFactory(url)
listenWS(factory)

reactor.run()
