
window.onload = ->
  depthCanvas     = document.getElementById('depth')
  depthCtx        = depthCanvas.getContext('2d')
  depthImage      = depthCtx.createImageData(depthCanvas.width, depthCanvas.height)
  depthImageData  = depthImage.data
  for i in [0..(depthImageData.length / 4 - 1)]
    depthImageData[i * 4 + 3] = 255  # make all pixels opaque
  
  dataCallback = (e) ->
    bytes = new Uint8Array(e.data)
    for byte, i in bytes
      offset = i * 4
      depthImageData[offset] = depthImageData[offset + 1] = depthImageData[offset + 2] = byte
    depthCtx.putImageData(depthImage, 0, 0)
    
  connect = ->
    url = 'ws://localhost:9000'
    reconnectDelay = 2
    console.log("Connecting to #{url} ...")
    ws = new WebSocket(url)
    ws.binaryType = 'arraybuffer'
    ws.onopen = -> console.log('Connected')
    ws.onclose = -> 
      console.log("Disconnected: retrying in #{reconnectDelay}s")
      setTimeout(connect, reconnectDelay * 1000)
    ws.onmessage = dataCallback
  
  connect()
