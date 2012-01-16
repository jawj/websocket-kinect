(function() {

  window.onload = function() {
    var animate, bgColour, camT, camZ, camZRange, camera, color, colorSet, connect, dataCallback, doCamPan, doCamZoom, down, dvp, fgColour, h, i, inputH, inputW, kvp, last, pMaterial, params, particle, particleSystem, particles, projector, renderer, scene, setSize, startCamPan, stats, stopCamPan, sx, sy, updateCamPos, useEvery, v, w, wls, x, xc, y, yc, _i, _len, _ref, _ref2;
    params = {
      stats: 0,
      zcolors: 0,
      fog: 1
    };
    wls = window.location.search;
    _ref = wls.substring(1).split('&');
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      kvp = _ref[_i];
      params[kvp.split('=')[0]] = parseInt(kvp.split('=')[1]);
    }
    if (params.stats) {
      stats = new Stats();
      stats.domElement.id = 'stats';
      document.body.appendChild(stats.domElement);
    }
    bgColour = 0x000000;
    fgColour = 0xffffff;
    colorSet = (function() {
      var _results;
      _results = [];
      for (i = 0; i <= 255; i++) {
        _results.push(new THREE.Color().setHSV(i / 255, 1, 1));
      }
      return _results;
    })();
    inputW = 640;
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
    camera = new THREE.PerspectiveCamera(45, 1, 1, 10000);
    dvp = (_ref2 = window.devicePixelRatio) != null ? _ref2 : 1;
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
    scene = new THREE.Scene();
    scene.add(camera);
    if (params.fog) scene.fog = new THREE.FogExp2(bgColour, 0.00033);
    projector = new THREE.Projector();
    pMaterial = new THREE.ParticleBasicMaterial({
      color: fgColour,
      size: useEvery * 3,
      vertexColors: params.zcolors
    });
    particles = new THREE.Geometry();
    for (y = 0; 0 <= h ? y < h : y > h; 0 <= h ? y++ : y--) {
      for (x = 0; 0 <= w ? x < w : x > w; 0 <= w ? x++ : x--) {
        xc = (x - (w / 2)) * useEvery * 2;
        yc = ((h / 2) - y) * useEvery * 2;
        particle = v(xc, yc, 0);
        particles.vertices.push(particle);
        color = new THREE.Color();
        if (params.zcolors) particles.colors.push(color);
      }
    }
    particleSystem = new THREE.ParticleSystem(particles, pMaterial);
    scene.add(particleSystem);
    down = false;
    sx = sy = 0;
    last = new Date().getTime();
    camZRange = [2200, 0];
    camZ = camZRange[0];
    camT = new Transform();
    animate = function() {
      renderer.clear();
      camera.lookAt(scene.position);
      renderer.render(scene, camera);
      window.requestAnimationFrame(animate, renderer.domElement);
      if (params.stats) return stats.update();
    };
    updateCamPos = function() {
      var _ref3;
      return _ref3 = camT.t(0, camZ), camera.position.x = _ref3[0], camera.position.z = _ref3[1], _ref3;
    };
    updateCamPos();
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
      var dx, dy, rotation;
      if (down) {
        dx = ev.clientX - sx;
        dy = ev.clientY - sy;
        rotation = dx * -0.0005 * Math.log(camZ);
        camT.rotate(rotation);
        updateCamPos();
        sx += dx;
        return sy += dy;
      }
    };
    $(renderer.domElement).on('mousemove', doCamPan);
    doCamZoom = function(ev, d, dX, dY) {
      camZ -= dY * 40;
      camZ = Math.max(camZ, camZRange[1]);
      camZ = Math.min(camZ, camZRange[0]);
      return updateCamPos();
    };
    $(renderer.domElement).on('mousewheel', doCamZoom);
    dataCallback = function(e) {
      var byte, bytes, bzipped, c, i, pc, pcs, pv, pvs, _len2;
      bzipped = new Uint8Array(e.data);
      bytes = rawStringToUint8Array(bzip2.simple(bzip2.array(bzipped)));
      c = params.zcolors;
      pvs = particles.vertices;
      if (c) pcs = particles.colors;
      for (i = 0, _len2 = bytes.length; i < _len2; i++) {
        byte = bytes[i];
        pv = pvs[i];
        if (c) pc = pcs[i];
        pv.position.z = (255 - byte) * 10;
        if (c) pc.copy(colorSet[byte]);
      }
      particleSystem.geometry.__dirtyVertices = true;
      if (c) return particleSystem.geometry.__dirtyColors = true;
    };
    connect = function() {
      var reconnectDelay, url, ws;
      url = 'ws://128.40.47.71:9000';
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
