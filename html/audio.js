(() => {
  const ctx = new (window.AudioContext || window.webkitAudioContext)();
  const master = ctx.createGain();
  master.connect(ctx.destination);
  const buffers = {};
  const loading = {};
  const toWeb = (x, y, z) => [x, z, -y];

  function load(file) {
    if (buffers[file]) return Promise.resolve(buffers[file]);
    if (loading[file]) return loading[file];
    loading[file] = fetch(`sounds/${file}.ogg`)
      .then((r) => r.arrayBuffer())
      .then((b) => ctx.decodeAudioData(b))
      .then((buf) => {
        buffers[file] = buf;
        return buf;
      })
      .catch(() => {
        delete loading[file];
      });
    return loading[file];
  }

  function set(param, value) {
    param.setTargetAtTime(value, ctx.currentTime, 0.02);
  }

  function listener(d) {
    const L = ctx.listener;
    const p = toWeb(d.x, d.y, d.z);
    const f = toWeb(d.fx, d.fy, d.fz);
    const u = toWeb(d.ux, d.uy, d.uz);
    if (L.positionX) {
      set(L.positionX, p[0]);
      set(L.positionY, p[1]);
      set(L.positionZ, p[2]);
      set(L.forwardX, f[0]);
      set(L.forwardY, f[1]);
      set(L.forwardZ, f[2]);
      set(L.upX, u[0]);
      set(L.upY, u[1]);
      set(L.upZ, u[2]);
    } else {
      L.setPosition(...p);
      L.setOrientation(...f, ...u);
    }
  }

  async function play(d) {
    if (ctx.state === 'suspended') ctx.resume();
    const buf = await load(d.file);
    if (!buf) return;
    const src = ctx.createBufferSource();
    src.buffer = buf;
    src.playbackRate.value = d.rate || 1.0;
    const gain = ctx.createGain();
    gain.gain.value = d.volume ?? 1.0;
    const pan = ctx.createPanner();
    pan.panningModel = 'HRTF';
    pan.distanceModel = 'inverse';
    pan.refDistance = d.ref || 3;
    pan.maxDistance = d.max || 45;
    pan.rolloffFactor = d.rolloff || 1.3;
    const p = toWeb(d.x, d.y, d.z);
    if (pan.positionX) {
      pan.positionX.value = p[0];
      pan.positionY.value = p[1];
      pan.positionZ.value = p[2];
    } else {
      pan.setPosition(...p);
    }
    src.connect(gain).connect(pan).connect(master);
    src.start();
  }

  window.addEventListener('message', (e) => {
    const d = e.data;
    if (!d || !d.whipAudio) return;
    if (d.type === 'listener') listener(d);
    else if (d.type === 'play') play(d);
  });
})();
