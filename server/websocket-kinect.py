#!/usr/bin/env python

import sys, signal, numpy, freenect, pylzma
from twisted.internet import reactor, threads
from autobahn.websocket import WebSocketServerFactory, WebSocketServerProtocol, listenWS, WebSocketClientFactory, WebSocketClientProtocol, connectWS


class SendClientProtocol(WebSocketClientProtocol):

  def onOpen(self):
    self.factory.register(self)
    
  def connectionLost(self, reason):
    WebSocketClientProtocol.connectionLost(self, reason)
    self.factory.unregister(self)
    
class SendClientFactory(WebSocketClientFactory):
  
  protocol = SendClientProtocol

  def __init__(self, url):
    WebSocketClientFactory.__init__(self, url)
    self.protocolInstance = None
    self.tickSetup()

  def tickSetup(self):
    self.dataSent = 0
    reactor.callLater(1, self.tick)

  def tick(self):
    print 'sent: %d bytes/sec' % self.dataSent
    self.tickSetup()

  def register(self, protocolInstance):
    self.protocolInstance = protocolInstance
    
  def unregister(self, protocolInstance):
    self.protocolInstance = None
  
  def broadcast(self, msg, binary):
    self.dataSent += len(msg)
    if self.protocolInstance == None:
      return
    self.protocolInstance.sendMessage(msg, binary)


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
    self.tickSetup()
    
  def tickSetup(self):
    self.dataSent = 0
    reactor.callLater(1, self.tick)
  
  def tick(self):
    print 'broadcast: %d bytes/sec' % self.dataSent
    self.tickSetup()
  
  def register(self, client):
    if not client in self.clients:
      print "registered client: " + client.peerstr
      self.clients.append(client)
  
  def unregister(self, client):
    if client in self.clients:
      print "unregistered client: " + client.peerstr
      self.clients.remove(client)
  
  def broadcast(self, msg, binary = False):
    self.dataSent += len(msg)
    for c in self.clients:
      c.sendMessage(msg, binary)


class Kinect:
  
  def __init__(self):
    useEvery = 4
    self.h = 480 / useEvery
    self.w = 640 / useEvery
    self.useCols, self.useRows = numpy.indices((self.h, self.w))
    self.useCols *= useEvery
    self.useRows *= useEvery
    
    self.keyFrameEvery = 30
    self.currentFrame = 0
  
  def depthCallback(self, dev, depth, timestamp):
    # resize grid
    depth = depth[self.useCols, self.useRows]
    
    # rescale depths
    numpy.clip(depth, 0, 2 ** 10 - 1, depth)
    depth >>= 2
    
    # calculate quadrant averages
    h, w = self.h, self.w
    halfH, halfW = h / 2, w / 2
    qtl = numpy.mean(depth[0:halfH, 0:halfW])
    qtr = numpy.mean(depth[0:halfH, halfW:w])
    qbl = numpy.mean(depth[halfH:h, 0:halfW])
    qbr = numpy.mean(depth[halfH:h, halfW:w])
    
    # calculate diff from last frame (unless it's a keyframe)
    keyFrame = self.currentFrame == 0
    diffDepth = depth if keyFrame else (depth - self.lastDepth) % 256

    # smush data together
    data = numpy.concatenate(([keyFrame, qtl, qtr, qbl, qbr], diffDepth.ravel()))
    
    # compress and broadcast
    crunchedData = pylzma.compress(data.astype(numpy.uint8), dictionary = 20)  # default dict: 23 -> 2 ** 23 -> 8MB
    reactor.callFromThread(factory.broadcast, crunchedData, True)
    
    # setup for next frame
    self.lastDepth = depth
    self.currentFrame += 1
    self.currentFrame %= self.keyFrameEvery
  
  def bodyCallback(self, *args):
    if not self.kinecting: raise freenect.Kill
  
  def run(self):
    self.kinecting = True
    reactor.callInThread(freenect.runloop, depth = self.depthCallback, body = self.bodyCallback)
  
  def stop(self):
    self.kinecting = False


def signalHandler(signum, frame):
  kinect.stop()
  reactor.stop()

func = sys.argv[1] if len(sys.argv) > 1 else 'server'
url  = sys.argv[2] if len(sys.argv) > 2 else 'ws://localhost:9000'

signal.signal(signal.SIGINT, signalHandler)
print '>>> %s --- Press Ctrl-C to stop <<<' % url

kinect = Kinect()
kinect.run()

if func == 'server':
  factory = BroadcastServerFactory(url)
  listenWS(factory)
else:
  factory = SendClientFactory(url)
  connectWS(factory)

reactor.run()
