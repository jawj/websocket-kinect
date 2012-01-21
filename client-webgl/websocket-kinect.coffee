
$ ->
  unless window.WebGLRenderingContext and document.createElement('canvas').getContext('experimental-webgl') and window.WebSocket and new WebSocket('ws://.').binaryType
    # no point testing for plain 'webgl' context, because Three.js doesn't
    $('#noWebGL').show()
    return
  
  params = 
    stats:   0
    fog:     1
    credits: 1
  wls = window.location.search
  (params[kvp.split('=')[0]] = parseInt(kvp.split('=')[1])) for kvp in wls.substring(1).split('&')
  
  $('#creditOuter').show() if params.credits
  
  if params.stats
    stats = new Stats()
    stats.domElement.id = 'stats'
    document.body.appendChild(stats.domElement)
  
  bgColour = 0x000000
  fgColour = 0xffffff

  inputW = 640
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
  
  scene = new THREE.Scene()
  scene.add(camera)
  scene.fog = new THREE.FogExp2(bgColour, 0.00033) if params.fog
  
  projector = new THREE.Projector()
  
  pMaterial = new THREE.ParticleBasicMaterial(color: fgColour, size: useEvery * 3)
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
  
  down = no
  sx = 0
  camZRange = [2000, 0]
  camZ = 1000
  camT = new Transform()
  mouseY = window.innerHeight / 2
  
  animate = ->
    renderer.clear()
    [camera.position.x, camera.position.z] = camT.t(0.01 * camZ * ((qtr + qbr) - (qtl + qbl)), camZ)
    camera.position.y = mouseY - window.innerHeight / 2
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
    mouseY = ev.clientY
    if down
      dx = ev.clientX - sx
      rotation = dx * -0.0005 * Math.log(camZ)
      camT.rotate(rotation)
      sx += dx
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
    url = 'ws://128.40.47.71:9000'
    reconnectDelay = 2
    console.log("Connecting to #{url} ...")
    ws = new WebSocket(url)
    ws.binaryType = 'arraybuffer'
    seenKeyFrame = no
    ws.onopen = -> console.log('Connected')
    ws.onclose = -> 
      console.log("Disconnected: retrying in #{reconnectDelay}s")
      setTimeout(connect, reconnectDelay * 1000)
    ws.onmessage = dataCallback
  
  connect()
