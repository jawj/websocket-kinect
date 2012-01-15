(function() {

  window.onload = function() {
    var connect, dataCallback, depthCanvas, depthCtx, depthImage, depthImageData, i, _ref;
    depthCanvas = document.getElementById('depth');
    depthCtx = depthCanvas.getContext('2d');
    depthImage = depthCtx.createImageData(depthCanvas.width, depthCanvas.height);
    depthImageData = depthImage.data;
    for (i = 0, _ref = depthImageData.length / 4 - 1; 0 <= _ref ? i <= _ref : i >= _ref; 0 <= _ref ? i++ : i--) {
      depthImageData[i * 4 + 3] = 255;
    }
    dataCallback = function(e) {
      var byte, bytes, i, offset, _len;
      bytes = new Uint8Array(e.data);
      for (i = 0, _len = bytes.length; i < _len; i++) {
        byte = bytes[i];
        offset = i * 4;
        depthImageData[offset] = depthImageData[offset + 1] = depthImageData[offset + 2] = byte;
      }
      return depthCtx.putImageData(depthImage, 0, 0);
    };
    connect = function() {
      var reconnectDelay, url, ws;
      url = 'ws://localhost:9000';
      reconnectDelay = 2;
      console.log("Connecting to " + url + " ...");
      ws = new WebSocket(url);
      ws.binaryType = 'arraybuffer';
      ws.onopen = function() {
        return console.log('Connected');
      };
      ws.onclose = function() {
        console.log("Disconnected: retrying in " + reconnectDelay + "s");
        return setTimeout(connect, reconnectDelay * 1000);
      };
      return ws.onmessage = dataCallback;
    };
    return connect();
  };

}).call(this);
