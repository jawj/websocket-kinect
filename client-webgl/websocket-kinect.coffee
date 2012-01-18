
window.onload = ->
  
  params = 
    stats:   0
    zcolors: 0
    fog:     1
  wls = window.location.search
  (params[kvp.split('=')[0]] = parseInt(kvp.split('=')[1])) for kvp in wls.substring(1).split('&')
  
  if params.stats
    stats = new Stats()
    stats.domElement.id = 'stats'
    document.body.appendChild(stats.domElement)
  
  bgColour = 0x000000
  fgColour = 0xffffff
  
  colorSet = for i in [0..255]
    new THREE.Color().setHSV(i / 255, 1, 1)

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
  
  pMaterial = new THREE.ParticleBasicMaterial(color: fgColour, size: useEvery * 3, vertexColors: params.zcolors)
  particles = new THREE.Geometry()
  for y in [0...h]
    for x in [0...w]
      xc = (x - (w / 2)) * useEvery * 2
      yc = ((h / 2) - y) * useEvery * 2
      particle = v(xc, yc, 0)
      particle.usualY = yc
      particles.vertices.push(particle)
      color = new THREE.Color()
      particles.colors.push(color) if params.zcolors
  
  particleSystem = new THREE.ParticleSystem(particles, pMaterial)
  scene.add(particleSystem)
  
  down = no
  sx = sy = 0
  last = new Date().getTime()
  camZRange = [1500, 0]
  camZ = camZRange[0]
  camT = new Transform()
  
  animate = ->
    renderer.clear()
    camera.lookAt(scene.position)
    renderer.render(scene, camera)
    window.requestAnimationFrame(animate, renderer.domElement)
    stats.update() if params.stats
    
  updateCamPos = -> [camera.position.x, camera.position.z] = camT.t(0, camZ)
  
  updateCamPos()
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
      rotation = dx * -0.0005 * Math.log(camZ)
      camT.rotate(rotation)
      updateCamPos()
      sx += dx; sy += dy
  $(renderer.domElement).on('mousemove', doCamPan)
  
  doCamZoom = (ev, d, dX, dY) ->
    camZ -= dY * 40
    camZ = Math.max(camZ, camZRange[1])
    camZ = Math.min(camZ, camZRange[0])
    updateCamPos()
  $(renderer.domElement).on('mousewheel', doCamZoom)
  
  seenKeyFrame = prevBytes = null  # scoping
  zc  = params.zcolors
  pvs = particles.vertices
  pcs = particles.colors if zc
  outArrays = [new Uint8Array(new ArrayBuffer(pvs.length)), new Uint8Array(new ArrayBuffer(pvs.length))]  # need 2 because one becomes prevBytes
  
  dataCallback = (e) ->
    frameNo = new Uint8Array(e.data, 0, 1)[0]
    return unless frameNo is 0 or seenKeyFrame
    seenKeyFrame = yes
    
    inStream  = LZMA.wrapArrayBuffer(new Uint8Array(e.data, 1, e.data.byteLength - 1))
    outStream = LZMA.wrapArrayBuffer(outArrays[frameNo % 2])
    LZMA.decompress(inStream, inStream, outStream, pvs.length)
    bytes = outStream.data
    
    for byte, i in bytes
      pv = pvs[i]
      pc = pcs[i] if zc
      bytes[i] = byte = (prevBytes[i] + byte) % 256 if frameNo > 0
      if byte is 255
        pv.position.y = -5000
      else
        pv.position.y = pv.usualY
        depth = 128 - byte
        pv.position.z = depth * 10
        pc.copy(colorSet[byte]) if zc
      
    prevBytes = bytes
    particleSystem.geometry.__dirtyVertices = yes
    particleSystem.geometry.__dirtyColors   = yes if zc
    
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
