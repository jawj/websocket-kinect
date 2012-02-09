
$ ->
  unless window.WebGLRenderingContext and document.createElement('canvas').getContext('experimental-webgl') and window.WebSocket and new WebSocket('ws://.').binaryType
    # no point testing for plain 'webgl' context, because Three.js doesn't
    $('#noWebGL').show()
    return
  
  params = 
    stats:   0
    fog:     1
    credits: 1
    ws:      "ws://#{window.location.host}"
  wls = window.location.search
  for kvp in wls.substring(1).split('&')
    [k, v] = kvp.split('=')
    params[k] = if k is 'ws' then v else parseInt(v)
  
  $('#creditOuter').show() if params.credits
  
  if params.stats
    stats = new Stats()
    stats.domElement.id = 'stats'
    document.body.appendChild(stats.domElement)
  
  bgColour = 0x000000
  fgColour = 0xffffff

  inputW = 632
  inputH = 480
  useEvery = 4
  w = inputW / useEvery
  h = inputH / useEvery
  
  Transform::t = Transform::transformPoint
  v = (x, y, z) -> new THREE.Vertex(new THREE.Vector3(x, y, z))
  
  renderer = new THREE.WebGLRenderer(antialias: true)
  camera = new THREE.PerspectiveCamera(60, 1, 1, 10000)  # aspect (2nd param) shortly to be overridden...
  
  dvp = window.devicePixelRatio ? 1
  setSize = ->
    renderer.setSize(window.innerWidth * dvp, window.innerHeight * dvp)
    renderer.domElement.style.width  = window.innerWidth + 'px'
    renderer.domElement.style.height = window.innerHeight + 'px'
    camera.aspect = window.innerWidth / window.innerHeight
    camera.updateProjectionMatrix()
  setSize()
  $(window).on('resize', setSize)
  
  document.body.appendChild(renderer.domElement)
  renderer.setClearColorHex(bgColour, 1.0)
  renderer.clear()
  
  projector = new THREE.Projector()
  scene = new THREE.Scene()
  scene.add(camera)
  scene.fog = new THREE.FogExp2(bgColour, 0.00033) if params.fog
  
  pMaterial = new THREE.ParticleBasicMaterial(color: fgColour, size: useEvery * 3.5)
  particles = new THREE.Geometry()
  for y in [0...h]
    for x in [0...w]
      xc = (x - (w / 2)) * useEvery * 2
      yc = ((h / 2) - y) * useEvery * 2
      particle = v(xc, yc, 0)
      particle.usualY = yc
      particles.vertices.push(particle)
  
  particleSystem = new THREE.ParticleSystem(particles, pMaterial)
  scene.add(particleSystem)
  
  togglePlay = ->
    
  drawControl = (playing) ->
    cvs = $('#control')[0]
    ctx = cvs.getContext('2d')
    ctx.fillStyle = '#fff'
    if playing  # square -> stop
      ctx.fillRect(0, 0, cvs.width, cvs.height)  
    else  # triangle -> play
      ctx.clearRect(0, 0, cvs.width, cvs.height)
      ctx.moveTo(0, 0)
      ctx.lineTo(cvs.width, cvs.height / 2)
      ctx.lineTo(0, cvs.height)
      ctx.fill()
  
  drawControl(false)
  
  down = no
  dynaPan = 0
  sx = sy = 0
  camZRange = [2000, 200]
  camZ = 880
  camYRange = [-600, 600]
  camT = new Transform()
  
  animate = ->
    renderer.clear()
    [camera.position.x, camera.position.z] = camT.t(0.01 * camZ * dynaPan, camZ)
    camera.lookAt(scene.position)
    renderer.render(scene, camera)
    window.requestAnimationFrame(animate, renderer.domElement)
    stats.update() if params.stats
    
  animate()
  
  startCamPan = (ev) ->
    down = yes
    sx = ev.clientX
    sy = ev.clientY
  $(renderer.domElement).on('mousedown', startCamPan)

  stopCamPan = -> 
    down = no
  $(renderer.domElement).on('mouseup', stopCamPan)

  doCamPan = (ev) ->
    if down
      dx = ev.clientX - sx
      dy = ev.clientY - sy
      rotation = dx * 0.0005 * Math.log(camZ)
      camT.rotate(rotation)
      camY = camera.position.y
      camY += dy * 3
      camY = camYRange[0] if camY < camYRange[0]
      camY = camYRange[1] if camY > camYRange[1]
      camera.position.y = camY
      sx += dx
      sy += dy
  $(renderer.domElement).on('mousemove', doCamPan)
  
  doCamZoom = (ev, d, dX, dY) ->
    camZ -= dY * 40
    camZ = Math.max(camZ, camZRange[1])
    camZ = Math.min(camZ, camZRange[0])
  $(renderer.domElement).on('mousewheel', doCamZoom)
  
  # scoping
  seenKeyFrame = null  
  qtl = qtr = qbl = qbr = null
  
  pvs  = particles.vertices
  pLen = pvs.length
  rawDataLen = 5 + pLen
  
  outArrays = for i in [0..1]
    new Uint8Array(new ArrayBuffer(rawDataLen))
  [currentOutArrayIdx, prevOutArrayIdx] = [0, 1]

  dataCallback = (e) ->
    [currentOutArrayIdx, prevOutArrayIdx] = [prevOutArrayIdx, currentOutArrayIdx]
    inStream  = LZMA.wrapArrayBuffer(new Uint8Array(e.data))
    outStream = LZMA.wrapArrayBuffer(outArrays[currentOutArrayIdx])
    LZMA.decompress(inStream, inStream, outStream, rawDataLen)
    bytes = outStream.data
    prevBytes = outArrays[prevOutArrayIdx]
    
    keyFrame = bytes[0]
    return unless keyFrame or seenKeyFrame
    seenKeyFrame = yes
    
    [qtl, qtr, qbl, qbr] = [bytes[1], bytes[2], bytes[3], bytes[4]]
    dynaPan = dynaPan * 0.9 + ((qtr + qbr) - (qtl + qbl)) * 0.1
    
    pIdx    = 0
    byteIdx = 5
    
    for y in [0...h]
      for x in [0...w]
        pv = pvs[pIdx]
        aByte = bytes[byteIdx]
        aByte = bytes[byteIdx] = (prevBytes[byteIdx] + aByte) % 256 unless keyFrame
        if aByte is 255
          pv.position.y = -5000  # = out of sight
        else
          pv.position.y = pv.usualY
          depth = 128 - aByte
          pv.position.z = depth * 10
        pIdx    += 1
        byteIdx += 1
        
    particleSystem.geometry.__dirtyVertices = yes
    
  connect = ->
    reconnectDelay = 10
    console.log("Connecting to #{params.ws} ...")
    ws = new WebSocket(params.ws)
    ws.binaryType = 'arraybuffer'
    seenKeyFrame = no
    ws.onopen = -> console.log('Connected')
    ws.onclose = -> 
      console.log("Disconnected: retrying in #{reconnectDelay}s")
      setTimeout(connect, reconnectDelay * 1000)
    ws.onmessage = dataCallback
  
  connect()
