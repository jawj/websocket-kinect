(function() {

  $(function() {
    var animate, bgColour, camT, camYRange, camZ, camZRange, camera, connect, currentOutArrayIdx, dataCallback, doCamPan, doCamZoom, down, drawControl, dvp, dynaPan, fgColour, h, i, inputH, inputW, k, kvp, outArrays, pLen, pMaterial, params, particle, particleSystem, particles, prevOutArrayIdx, projector, pvs, qbl, qbr, qtl, qtr, rawDataLen, renderer, scene, seenKeyFrame, setSize, startCamPan, stats, stopCamPan, sx, sy, togglePlay, useEvery, v, w, wls, x, xc, y, yc, _i, _len, _ref, _ref2, _ref3, _ref4;
    if (!(window.WebGLRenderingContext && document.createElement('canvas').getContext('experimental-webgl') && window.WebSocket && new WebSocket('ws://.').binaryType)) {
      $('#noWebGL').show();
      return;
    }
    params = {
      stats: 0,
      fog: 1,
      credits: 1,
      ws: "ws://" + window.location.host
    };
    wls = window.location.search;
    _ref = wls.substring(1).split('&');
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      kvp = _ref[_i];
      _ref2 = kvp.split('='), k = _ref2[0], v = _ref2[1];
      params[k] = k === 'ws' ? v : parseInt(v);
    }
    if (params.credits) $('#creditOuter').show();
    if (params.stats) {
      stats = new Stats();
      stats.domElement.id = 'stats';
      document.body.appendChild(stats.domElement);
    }
    bgColour = 0x000000;
    fgColour = 0xffffff;
    inputW = 632;
    inputH = 480;
    useEvery = 4;
    w = inputW / useEvery;
    h = inputH / useEvery;
    Transform.prototype.t = Transform.prototype.transformPoint;
    v = function(x, y, z) {
      return new THREE.Vertex(new THREE.Vector3(x, y, z));
    };
    renderer = new THREE.WebGLRenderer({
      antialias: true
    });
    camera = new THREE.PerspectiveCamera(60, 1, 1, 10000);
    dvp = (_ref3 = window.devicePixelRatio) != null ? _ref3 : 1;
    setSize = function() {
      renderer.setSize(window.innerWidth * dvp, window.innerHeight * dvp);
      renderer.domElement.style.width = window.innerWidth + 'px';
      renderer.domElement.style.height = window.innerHeight + 'px';
      camera.aspect = window.innerWidth / window.innerHeight;
      return camera.updateProjectionMatrix();
    };
    setSize();
    $(window).on('resize', setSize);
    document.body.appendChild(renderer.domElement);
    renderer.setClearColorHex(bgColour, 1.0);
    renderer.clear();
    projector = new THREE.Projector();
    scene = new THREE.Scene();
    scene.add(camera);
    if (params.fog) scene.fog = new THREE.FogExp2(bgColour, 0.00033);
    pMaterial = new THREE.ParticleBasicMaterial({
      color: fgColour,
      size: useEvery * 3.5
    });
    particles = new THREE.Geometry();
    for (y = 0; 0 <= h ? y < h : y > h; 0 <= h ? y++ : y--) {
      for (x = 0; 0 <= w ? x < w : x > w; 0 <= w ? x++ : x--) {
        xc = (x - (w / 2)) * useEvery * 2;
        yc = ((h / 2) - y) * useEvery * 2;
        particle = v(xc, yc, 0);
        particle.usualY = yc;
        particles.vertices.push(particle);
      }
    }
    particleSystem = new THREE.ParticleSystem(particles, pMaterial);
    scene.add(particleSystem);
    togglePlay = function() {};
    drawControl = function(playing) {
      var ctx, cvs;
      cvs = $('#control')[0];
      ctx = cvs.getContext('2d');
      ctx.fillStyle = '#fff';
      if (playing) {
        return ctx.fillRect(0, 0, cvs.width, cvs.height);
      } else {
        ctx.clearRect(0, 0, cvs.width, cvs.height);
        ctx.moveTo(0, 0);
        ctx.lineTo(cvs.width, cvs.height / 2);
        ctx.lineTo(0, cvs.height);
        return ctx.fill();
      }
    };
    drawControl(false);
    down = false;
    dynaPan = 0;
    sx = sy = 0;
    camZRange = [2000, 200];
    camZ = 880;
    camYRange = [-600, 600];
    camT = new Transform();
    animate = function() {
      var _ref4;
      renderer.clear();
      _ref4 = camT.t(0.01 * camZ * dynaPan, camZ), camera.position.x = _ref4[0], camera.position.z = _ref4[1];
      camera.lookAt(scene.position);
      renderer.render(scene, camera);
      window.requestAnimationFrame(animate, renderer.domElement);
      if (params.stats) return stats.update();
    };
    animate();
    startCamPan = function(ev) {
      down = true;
      sx = ev.clientX;
      return sy = ev.clientY;
    };
    $(renderer.domElement).on('mousedown', startCamPan);
    stopCamPan = function() {
      return down = false;
    };
    $(renderer.domElement).on('mouseup', stopCamPan);
    doCamPan = function(ev) {
      var camY, dx, dy, rotation;
      if (down) {
        dx = ev.clientX - sx;
        dy = ev.clientY - sy;
        rotation = dx * 0.0005 * Math.log(camZ);
        camT.rotate(rotation);
        camY = camera.position.y;
        camY += dy * 3;
        if (camY < camYRange[0]) camY = camYRange[0];
        if (camY > camYRange[1]) camY = camYRange[1];
        camera.position.y = camY;
        sx += dx;
        return sy += dy;
      }
    };
    $(renderer.domElement).on('mousemove', doCamPan);
    doCamZoom = function(ev, d, dX, dY) {
      camZ -= dY * 40;
      camZ = Math.max(camZ, camZRange[1]);
      return camZ = Math.min(camZ, camZRange[0]);
    };
    $(renderer.domElement).on('mousewheel', doCamZoom);
    seenKeyFrame = null;
    qtl = qtr = qbl = qbr = null;
    pvs = particles.vertices;
    pLen = pvs.length;
    rawDataLen = 5 + pLen;
    outArrays = (function() {
      var _results;
      _results = [];
      for (i = 0; i <= 1; i++) {
        _results.push(new Uint8Array(new ArrayBuffer(rawDataLen)));
      }
      return _results;
    })();
    _ref4 = [0, 1], currentOutArrayIdx = _ref4[0], prevOutArrayIdx = _ref4[1];
    dataCallback = function(e) {
      var aByte, byteIdx, bytes, depth, inStream, keyFrame, outStream, pIdx, prevBytes, pv, x, y, _ref5, _ref6;
      _ref5 = [prevOutArrayIdx, currentOutArrayIdx], currentOutArrayIdx = _ref5[0], prevOutArrayIdx = _ref5[1];
      inStream = LZMA.wrapArrayBuffer(new Uint8Array(e.data));
      outStream = LZMA.wrapArrayBuffer(outArrays[currentOutArrayIdx]);
      LZMA.decompress(inStream, inStream, outStream, rawDataLen);
      bytes = outStream.data;
      prevBytes = outArrays[prevOutArrayIdx];
      keyFrame = bytes[0];
      if (!(keyFrame || seenKeyFrame)) return;
      seenKeyFrame = true;
      _ref6 = [bytes[1], bytes[2], bytes[3], bytes[4]], qtl = _ref6[0], qtr = _ref6[1], qbl = _ref6[2], qbr = _ref6[3];
      dynaPan = dynaPan * 0.9 + ((qtr + qbr) - (qtl + qbl)) * 0.1;
      pIdx = 0;
      byteIdx = 5;
      for (y = 0; 0 <= h ? y < h : y > h; 0 <= h ? y++ : y--) {
        for (x = 0; 0 <= w ? x < w : x > w; 0 <= w ? x++ : x--) {
          pv = pvs[pIdx];
          aByte = bytes[byteIdx];
          if (!keyFrame) {
            aByte = bytes[byteIdx] = (prevBytes[byteIdx] + aByte) % 256;
          }
          if (aByte === 255) {
            pv.position.y = -5000;
          } else {
            pv.position.y = pv.usualY;
            depth = 128 - aByte;
            pv.position.z = depth * 10;
          }
          pIdx += 1;
          byteIdx += 1;
        }
      }
      return particleSystem.geometry.__dirtyVertices = true;
    };
    connect = function() {
      var reconnectDelay, ws;
      reconnectDelay = 10;
      console.log("Connecting to " + params.ws + " ...");
      ws = new WebSocket(params.ws);
      ws.binaryType = 'arraybuffer';
      seenKeyFrame = false;
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
  });

}).call(this);
