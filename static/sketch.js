// MemoryGarden — p5.js port of MemoryGarden.pde
// ---------------------------------------------------------------------------

let clusters = [];
let centerName = "";
let allClusters = [];
let shuffleQueue = [];
let queuePos = 0;
let gardenData = null;

const TOP_MARGIN = 46;
const CELL_W = 800;
const ROW_H = 754;

// Module-level drawing target — mirrors Processing's `g = pgHead` trick.
// In normal draw(), _g delegates to global p5 functions (main canvas).
// During export, _g is set to a p5.Graphics buffer.
let _g = null;

// Build a pass-through object that delegates to p5 global functions.
// This lets us write _g.fill(), _g.ellipse() etc. uniformly.
// Helper to sync colorMode on both global canvas and _g (if offscreen buffer)
let _globalDrawer = null;
function _cm(...args) {
  colorMode(...args);
  if (_g && _g !== _globalDrawer) _g.colorMode(...args);
}

function buildGlobalDrawer() {
  const methods = [
    "push","pop","translate","rotate","scale",
    "fill","stroke","noFill","noStroke","strokeWeight",
    "beginShape","endShape","vertex","bezierVertex",
    "bezier","ellipse","line","rect",
    "text","textSize","textAlign",
    "background","loadPixels","image","colorMode"
  ];
  let obj = {};
  for (let m of methods) {
    // Use a getter so we always get the current global function
    Object.defineProperty(obj, m, {
      get() { return window[m]; }
    });
  }
  return obj;
}

// UI callback hooks (set by index.html)
let onFlowerRebuilt = null; // called after flower rebuild with current features

// ── Preload ─────────────────────────────────────────────────────────────────
function preload() {
  window._p5PreloadRan = true;
  gardenData = loadJSON("/api/garden");
}

// ── Setup ───────────────────────────────────────────────────────────────────
function setup() {
  window._p5SetupRan = true;
  let cnv = createCanvas(800, 800);
  cnv.parent("canvas-container");
  _g = buildGlobalDrawer();
  _globalDrawer = _g;

  centerName = gardenData.center_name || "";
  allClusters = gardenData.all_clusters || [];

  if (allClusters.length >= 1) {
    buildShuffleQueue();
    loadCurrentPage();
  }
}

// ── Draw ────────────────────────────────────────────────────────────────────
function draw() {
  for (let fc of clusters) fc.update();
  drawScene();
}

function drawScene() {
  background(248, 244, 235);

  // Title
  noStroke();
  fill(75, 65, 55);
  textSize(18);
  textAlign(LEFT, BASELINE);
  text("The Memory Garden of  " + centerName, 22, 32);

  // Header separator
  stroke(205, 195, 185, 140);
  strokeWeight(0.7);
  line(0, 43, width, 43);

  // Memory counter
  noStroke();
  fill(175, 155, 130, 180);
  textSize(12);
  textAlign(RIGHT, BASELINE);
  let total = allClusters.length || 1;
  let current = queuePos + 1;
  text(current + " / " + total, width - 18, 30);

  for (let fc of clusters) fc.draw();
}

// ── Keyboard ─────────────────────────────────────────────────────────────────
function keyPressed() {
  // Don't trigger shortcuts when typing in input fields
  if (document.activeElement && document.activeElement.tagName === "INPUT") return;
  if (document.activeElement && document.activeElement.tagName === "TEXTAREA") return;

  if (key === "r" || key === "R") shuffleGarden();
}

// ── Shuffle / navigation ─────────────────────────────────────────────────────
function shuffleGarden() {
  if (!allClusters || allClusters.length === 0) return;
  queuePos += 1;
  if (queuePos >= shuffleQueue.length) buildShuffleQueue();
  loadCurrentPage();
}

function buildShuffleQueue() {
  let n = allClusters.length;
  shuffleQueue = [];
  for (let i = 0; i < n; i++) shuffleQueue.push(i);
  // Fisher-Yates shuffle
  for (let i = n - 1; i > 0; i--) {
    let j = Math.floor(Math.random() * (i + 1));
    [shuffleQueue[i], shuffleQueue[j]] = [shuffleQueue[j], shuffleQueue[i]];
  }
  queuePos = 0;
}

function loadCurrentPage() {
  clusters = [];
  let qi = shuffleQueue[queuePos];
  clusters.push(new FlowerCluster(allClusters[qi], 0, TOP_MARGIN, 0));
  syncSlidersFromFlower();
}

// ── Slider sync ──────────────────────────────────────────────────────────────
function syncSlidersFromFlower() {
  if (clusters.length === 0) return;
  let feat = clusters[0].sourceFeatures;
  if (!feat) return;

  // Update the read-only feature display in the UI
  if (window._updateFeatureDisplay) window._updateFeatureDisplay(feat);
}

// rebuildFromSliders removed — features are now read-only display

// ── Export helpers ────────────────────────────────────────────────────────────
function exportFlowerBase64(mode) {
  if (clusters.length === 0) return null;
  let f = clusters[0].main;
  let SZ = 2048;

  let pg = createGraphics(SZ, SZ);

  if (mode === "head") {
    let sf = (SZ * 0.40) / (f.baseRadius * f.radiusJitter);
    pg.background(248, 244, 235);
    pg.translate(SZ * 0.5, SZ * 0.5);
    pg.scale(sf);

    let prevG = _g;
    _g = pg;
    f.drawHeadOnly();
    _g = prevG;

    pg.loadPixels();
    let b64 = pg.canvas.toDataURL("image/png");
    pg.remove();
    return b64;
  } else {
    // stem mode
    let totalH = f.stemHeight + f.baseRadius * f.radiusJitter * 1.4;
    let sfStem = (SZ * 0.88) / totalH;
    pg.background(248, 244, 235);
    let baseX = SZ * 0.5;
    let baseY = SZ - SZ * 0.08;
    pg.translate(baseX, baseY);
    pg.scale(sfStem);

    let prevG = _g;
    _g = pg;
    f.drawWithStem();
    _g = prevG;

    pg.loadPixels();
    let b64 = pg.canvas.toDataURL("image/png");
    pg.remove();
    return b64;
  }
}


// ── Color helpers ────────────────────────────────────────────────────────────
function wrapHue(h) {
  return ((h % 360) + 360) % 360;
}

function blendHue(a, b, amt) {
  let delta = ((b - a + 540) % 360) - 180;
  return wrapHue(a + delta * amt);
}

function semanticHue(valenceNorm, impact, togetherness, motion, lengthNorm) {
  let coolAnchor = 210 + motion * 20 - impact * 18;
  let warmAnchor = 28 + impact * 34 - motion * 10;
  let socialAnchor = 122 + togetherness * 36 - lengthNorm * 14;
  let dreamyAnchor = 286 + motion * 34 + impact * 10;
  let vividAnchor = 342 + lengthNorm * 32 - togetherness * 14;

  let sadBase = blendHue(coolAnchor, dreamyAnchor, 0.35 + motion * 0.25);
  let happyBase = blendHue(socialAnchor, warmAnchor, 0.30 + impact * 0.35);
  let neutralBase = blendHue(vividAnchor, socialAnchor, 0.45 + togetherness * 0.20);

  let h = blendHue(sadBase, happyBase, pow(valenceNorm, 0.78));
  h = blendHue(h, neutralBase, 0.16 + lengthNorm * 0.14);

  let featureSpin = impact * 80 + togetherness * 55 + motion * 95 + lengthNorm * 120;
  h = wrapHue(h + featureSpin);

  let accentRoll = random(1);
  if (accentRoll < 0.22) {
    h = blendHue(h, vividAnchor, random(0.20, 0.55));
  } else if (accentRoll < 0.44) {
    h = blendHue(h, warmAnchor, random(0.15, 0.45));
  } else if (accentRoll < 0.66) {
    h = blendHue(h, dreamyAnchor, random(0.18, 0.50));
  } else if (accentRoll < 0.84) {
    h = blendHue(h, coolAnchor, random(0.12, 0.35));
  }

  h += random(-38, 38) + map(lengthNorm, 0, 1, -18, 24);
  return wrapHue(h);
}

function buildSemanticFlowerColor(valence, impact, togetherness, motion, lengthNorm) {
  let valenceNorm = constrain((valence + 1.0) * 0.5, 0, 1);
  let h = semanticHue(valenceNorm, impact, togetherness, motion, lengthNorm);

  let satJitter = random(-16, 16);
  let brightJitter = random(-14, 14);
  let paletteLift = random(-12, 18);

  let sadSat = 10 + togetherness * 14 + lengthNorm * 12;
  let happySat = 58 + impact * 22 + togetherness * 12 + lengthNorm * 18;
  let altSat = 34 + motion * 18 + lengthNorm * 22;
  let s = lerp(sadSat, happySat, pow(valenceNorm, 0.70));
  s = lerp(s, altSat, random(0.12, 0.38));
  s += map(impact, 0, 1, -10, 10) - motion * 8 + satJitter + paletteLift;

  let sadBright = 38 + lengthNorm * 16 + impact * 6;
  let happyBright = 62 + impact * 18 + lengthNorm * 16;
  let altBright = 54 + togetherness * 10 + random(-8, 10);
  let b = lerp(sadBright, happyBright, pow(valenceNorm, 0.82));
  b = lerp(b, altBright, random(0.10, 0.34));
  b += togetherness * 6 - motion * 5 + brightJitter;

  colorMode(HSB, 360, 100, 100);
  let c = color(wrapHue(h), constrain(s, 10, 98), constrain(b, 26, 98));
  return c;
}

// ── FlowerCluster ────────────────────────────────────────────────────────────
class FlowerCluster {
  constructor(data, cellLeft, cellTop, idx) {
    this.cellLeft = cellLeft;
    this.cellTop = cellTop;
    this.clusterIdx = idx;
    this.theme = data.theme || "Memory";
    this.sourceFeatures = data.center ? data.center.features : null;

    let cx = cellLeft + CELL_W * 0.5;
    let mainStemY = cellTop + 560;

    this.main = new Flower(data.center, cx, mainStemY, true, idx * 10);
  }

  update() {
    this.main.update();
  }

  draw() {
    let mainEb = sin(this.main.bloom * HALF_PI);
    let textAlpha = constrain(map(mainEb, 0.1, 0.7, 0, 255), 0, 255);

    let textBoxBot = this.cellTop + 310;
    let cx = this.cellLeft + CELL_W * 0.5;
    let maxW = min(CELL_W - 80, 560);

    noStroke();

    let maxTextH = 110;
    textSize(20);
    textAlign(CENTER, TOP);
    let textTop = textBoxBot - maxTextH;

    fill(52, 46, 40, textAlpha);
    text(this.main.memory, cx - maxW / 2, textTop, maxW, maxTextH);

    // Theme
    textSize(26);
    textAlign(CENTER, TOP);
    fill(155, 115, 75, textAlpha);
    text("\u25C6  " + this.theme.toUpperCase() + "  \u25C6", cx, textTop - 50);

    // Flower
    this.main.draw();
  }
}

// ── Flower ───────────────────────────────────────────────────────────────────
class Flower {
  constructor(data, x, y, isMain, bloomDelay) {
    this.x = x;
    this.y = y;
    this.isMain = isMain;
    this.bloomDelay = bloomDelay;
    this.startFrame = frameCount;
    this.bloom = 0.0;
    this.cleanExportMode = false;

    this.memory = data.memory || "";

    let f = data.features;
    this.valence = f.valence;
    let impact = f.impact;
    let tog = f.togetherness;
    let motion = f.motion;
    let lengthNorm = f.length;
    let valenceNorm = constrain((this.valence + 1.0) * 0.5, 0, 1);

    // ── Colour ──────────────────────────────────────────────────────────
    colorMode(HSB, 360, 100, 100);
    this.col = buildSemanticFlowerColor(this.valence, impact, tog, motion, lengthNorm);
    let h = hue(this.col);
    let s = saturation(this.col);
    let b = brightness(this.col);

    this.shadowCol = color(h, s * 0.90, b * 0.46);
    this.centerCol = color(h, s * 0.24, min(98, b + 18));
    colorMode(RGB, 255);

    // ── Size and shape ──────────────────────────────────────────────────
    this.baseRadius = isMain
      ? map(impact, 0, 1, 41.6, 96.2)
      : map(impact, 0, 1, 18.2, 49.4);
    let impactShape = map(impact, 0, 1, 0.72, 0.18);
    let valenceShape = map(valenceNorm, 0, 1, 0.18, 1.05);
    this.sideRatio = lerp(impactShape, valenceShape, 0.70);

    // ── Petal count ─────────────────────────────────────────────────────
    this.numPetals = max(2, int(map(tog, 0, 1, 3, 10)) + int(random(-1, 2)));
    if (!isMain) this.numPetals = max(3, this.numPetals + int(random(-3, 3)));

    // ── Sway ────────────────────────────────────────────────────────────
    this.swaySpeed = map(motion, 0, 1, 0.008, 0.024);
    this.swayPhase = random(TWO_PI);

    // ── Stem height ─────────────────────────────────────────────────────
    this.stemHeight = isMain
      ? map(lengthNorm, 0, 1, 143, 260) * random(0.88, 1.14)
      : map(lengthNorm, 0, 1, 91, 188.5) * random(0.72, 1.32);

    // ── Droop ───────────────────────────────────────────────────────────
    this.tiltDir = random(1) < 0.5 ? -1 : 1;
    this.postureTilt = this.tiltDir * map(this.valence, -1, 1, radians(10), radians(-4));
    this.stemBend = this.tiltDir * (map(this.valence, -1, 1, 28, 5) + random(-4, 4));
    this.headNod = map(this.valence, -1, 1, radians(52), radians(-8));

    // ── Jitter ──────────────────────────────────────────────────────────
    this.radiusJitter = isMain ? random(0.88, 1.15) : random(0.65, 1.40);
    this.sideJitter = isMain ? random(0.80, 1.20) : random(0.60, 1.40);
    this.petalSpreadJitter = isMain
      ? random(-radians(8), radians(8))
      : random(-radians(18), radians(18));
    this.textureSeed = random(1000);

    // ── Per-flower style variation ──────────────────────────────────────
    this.outlineWeight = isMain
      ? map(impact, 0, 1, 0.5, 2.0)
      : map(impact, 0, 1, 0.3, 1.3);
    this.outlineAlpha = map(impact, 0, 1, 80, 210);

    colorMode(HSB, 360, 100, 100);
    this.outlineCol = color(
      hue(this.col),
      constrain(saturation(this.col) * 0.6, 15, 70),
      15 + impact * 10
    );
    let stemHue = lerp(115, hue(this.col), 0.35 + this.valence * 0.2);
    this.stemCol = color(
      stemHue,
      constrain(35 + saturation(this.col) * 0.3, 20, 60),
      45 + lengthNorm * 15
    );
    colorMode(RGB, 255);

    this.hatchDensity = motion * 0.7 + impact * 0.3;
    this.useStipple = noise(this.textureSeed * 0.37) < 0.20;
    this.curlIntensity =
      map(lengthNorm, 0, 1, 0.1, 1.0) *
      (0.5 + noise(this.textureSeed * 0.61) * 1.0);
    this.spatterDensity = noise(this.textureSeed * 0.43) * 0.6 + impact * 0.4;
    this.centreScale =
      map(impact, 0, 1, 0.7, 1.4) *
      (0.85 + noise(this.textureSeed * 0.29) * 0.3);
    this.ringSpread =
      map(tog, 0, 1, 1.3, 0.8) *
      (0.85 + noise(this.textureSeed * 0.51) * 0.3);
    this.petalLenVariance = 0.25 + random(0.35);
    this.angularChaos = 0.3 + random(0.7);
    this.ringCount = 2 + int(random(3));
    this.petalWidthWarp = random(0.75, 1.35);
  }

  update() {
    if (frameCount > this.startFrame + this.bloomDelay)
      this.bloom = min(this.bloom + 0.016, 1.0);
  }

  // ── drawHeadOnly ──────────────────────────────────────────────────────
  drawHeadOnly() {
    let eb = sin(this.bloom * HALF_PI);
    if (eb < 0.02) eb = 1.0;
    let r = this.baseRadius * this.radiusJitter * eb;
    this.cleanExportMode = true;
    this.drawAllPetals(r, eb);
    this.cleanExportMode = false;
    this.drawSpatter(r, eb, 0, 0);
  }

  // ── drawWithStem ──────────────────────────────────────────────────────
  drawWithStem() {
    let eb = sin(this.bloom * HALF_PI);
    if (eb < 0.02) eb = 1.0;

    let r = this.baseRadius * this.radiusJitter * eb;
    let sh = this.stemHeight * eb;
    let bend = this.stemBend * eb;

    // Stem
    let sc = this.stemCol;
    _cm(HSB, 360, 100, 100);
    _g.stroke(hue(sc), saturation(sc), brightness(sc), 200);
    _cm(RGB, 255);
    _g.strokeWeight(this.isMain ? 2.3 : 1.4);
    _g.noFill();
    _g.bezier(0, 0, 0, -sh * 0.88, bend, -sh * 0.96, bend, -sh);
    _g.noStroke();

    // Flower head
    _g.push();
    _g.translate(bend, -sh);
    _g.rotate(this.postureTilt + this.headNod * eb);
    this.cleanExportMode = true;
    this.drawAllPetals(r, eb);
    this.cleanExportMode = false;
    _g.pop();
    this.drawSpatter(r, eb, bend, -sh);
  }

  // ── draw (per-frame) ──────────────────────────────────────────────────
  draw() {
    let eb = sin(this.bloom * HALF_PI);
    if (eb < 0.02) return;

    let sway = sin(frameCount * this.swaySpeed + this.swayPhase) * 0.22 * eb;
    let r = this.baseRadius * this.radiusJitter * eb;
    let sh = this.stemHeight * eb;
    let lean = this.postureTilt * eb + sway * 0.80;
    let bend = this.stemBend * eb;
    let stemSway = sway * sh * 0.55;
    let sadness = constrain((-this.valence + 1.0) * 0.5, 0, 1);
    let headDropY = sh * pow(sadness, 1.6) * 0.72;

    push();
    translate(this.x, this.y);

    // ── Stem ──────────────────────────────────────────────────────────
    let sc = this.stemCol;
    _cm(HSB, 360, 100, 100);
    stroke(hue(sc), saturation(sc), brightness(sc), 200 * eb);
    _cm(RGB, 255);
    strokeWeight(this.isMain ? 2.3 : 1.4);
    noFill();
    bezier(
      0, 0,
      stemSway * 0.01, -sh * 0.88,
      bend + stemSway * 0.92, -sh * 0.96 + headDropY * 0.6,
      bend + stemSway, -sh + headDropY
    );
    noStroke();

    // ── Flower head ───────────────────────────────────────────────────
    translate(bend + stemSway, -sh + headDropY);
    rotate(lean + this.headNod * eb);

    // During normal draw, _g is the main canvas — use global functions
    this.drawAllPetals(r, eb);

    pop();

    // Spatter in screen space
    let headX = this.x + bend + stemSway * 0.55;
    let headY = this.y + (-sh + headDropY);
    this.drawSpatter(r, eb, headX, headY);
  }

  // ── drawAllPetals ─────────────────────────────────────────────────────
  drawAllPetals(r, eb) {
    if (this.numPetals <= 5) {
      let n = this.numPetals + int(noise(this.textureSeed * 0.44) * 2);
      let sparseR = r * (1.15 + noise(this.textureSeed * 0.19) * 0.35);
      let sparseOff = noise(this.textureSeed * 0.31) * TWO_PI;
      this.drawRing(
        n, sparseR, sparseOff,
        0.80 + noise(this.textureSeed * 0.57) * 0.4,
        0, eb, 0.40 + noise(this.textureSeed * 0.63) * 0.30
      );

      let accent = 1 + int(noise(this.textureSeed * 0.77) * 3);
      let accentOff = noise(this.textureSeed * 0.55) * TWO_PI;
      this.drawRing(
        accent,
        sparseR * (0.25 + noise(this.textureSeed * 0.83) * 0.20),
        accentOff, 1.0, 200, eb,
        0.35 + noise(this.textureSeed * 0.71) * 0.30
      );

      this.drawCentre(r * 1.3 * this.centreScale, eb);
      return;
    }

    // Full multi-ring bloom
    let ringRadii = [];
    let ringPetals = [];
    let ringOffs = [];
    let ringJitter = [];
    let ringWidth = [];

    for (let ri = 0; ri < this.ringCount; ri++) {
      let t = ri / (this.ringCount - 1 + 0.001);
      ringRadii.push(
        r * (0.90 - t * 0.65 + this.ringSpread * 0.20 * (1 - t)) *
        (0.85 + noise(this.textureSeed * (0.31 + ri * 0.17)) * 0.30)
      );
      ringPetals.push(
        max(3, this.numPetals + 3 - ri * 2 +
          int((noise(this.textureSeed * (0.53 + ri * 0.29)) - 0.5) * 4))
      );
      ringOffs.push(noise(this.textureSeed * (0.31 + ri * 0.36)) * TWO_PI);
      ringJitter.push(0.35 + t * 0.25 + this.angularChaos * 0.15);
      ringWidth.push(
        0.7 + (1 - t) * 0.3 +
        noise(this.textureSeed * (0.44 + ri * 0.23)) * 0.25
      );
    }

    for (let ri = 0; ri < this.ringCount; ri++) {
      this.drawRing(
        ringPetals[ri], ringRadii[ri], ringOffs[ri],
        ringJitter[ri], ri * 50, eb, ringWidth[ri]
      );
    }

    this.drawCentre(r * this.centreScale, eb);
  }

  // ── drawRing ──────────────────────────────────────────────────────────
  drawRing(n, r, baseOff, jitterAmt, seedOff, eb, widthScale) {
    for (let pass = 0; pass < 2; pass++) {
      let isShadow = pass === 0;
      for (let i = 0; i < n; i++) {
        let angJitter =
          (noise(this.textureSeed + seedOff + i * 3.7) - 0.5) *
          jitterAmt * this.angularChaos;
        let a = baseOff + (i * TWO_PI) / n + angJitter + this.petalSpreadJitter;
        let lenNoise = noise(this.textureSeed + seedOff + i * 1.1);
        let rJitter =
          r * (1.0 - this.petalLenVariance * 0.5 + lenNoise * this.petalLenVariance);
        let wScale =
          widthScale * this.petalWidthWarp *
          (0.8 + noise(this.textureSeed + seedOff + i * 5.3) * 0.4);
        this.drawPetal(a, rJitter, isShadow, seedOff + i, wScale);
      }
    }
  }

  // ── drawSpatter ───────────────────────────────────────────────────────
  drawSpatter(r, eb, cx, cy) {
    _g.noStroke();
    let nDots = int((this.isMain ? 55 : 30) * this.spatterDensity);
    for (let i = 0; i < nDots; i++) {
      let ang = noise(this.textureSeed + i * 4.7) * TWO_PI;
      let dist = r * (0.25 + noise(this.textureSeed + i * 3.1) * 1.1);
      let bx = cos(ang) * dist;
      let by = sin(ang) * dist;

      let driftSpeed = 0.008 + noise(this.textureSeed + i * 1.3) * 0.014;
      let driftPhase = noise(this.textureSeed + i * 9.7) * TWO_PI;
      let driftAmp = 1.5 + noise(this.textureSeed + i * 6.1) * 3.5;
      let dx = sin(frameCount * driftSpeed + driftPhase) * driftAmp;
      let dy = cos(frameCount * driftSpeed * 0.7 + driftPhase + 1.3) * driftAmp;

      let sz = 0.6 + noise(this.textureSeed + i * 6.3) * 3.2;

      _cm(HSB, 360, 100, 100);
      let h = hue(this.col) + (noise(this.textureSeed + i * 2.0) - 0.5) * 40;
      let s = 40 + noise(this.textureSeed + i * 8.0) * 50;
      let b = 30 + noise(this.textureSeed + i * 9.0) * 50;
      let a = (55 + noise(this.textureSeed + i * 1.5) * 140) * eb;
      _g.fill(h, s, b, a);
      _cm(RGB, 255);

      _g.ellipse(cx + bx + dx, cy + by + dy, sz, sz);
    }
  }

  // ── drawCentre ────────────────────────────────────────────────────────
  drawCentre(r, eb) {
    let discR = (this.isMain ? 18 : 11) * eb;
    _g.noStroke();

    for (let layer = 3; layer >= 0; layer--) {
      let lr = discR * (0.6 + layer * 0.15);
      let lAlpha = 180 + layer * 20;
      _cm(HSB, 360, 100, 100);
      _g.fill(hue(this.col), saturation(this.col) * 0.3, 12 + layer * 5, lAlpha);
      _cm(RGB, 255);
      let jx = (noise(this.textureSeed + layer * 3.3) - 0.5) * 3;
      let jy = (noise(this.textureSeed + layer * 5.5) - 0.5) * 3;
      _g.ellipse(jx, jy, lr * 2, lr * 2);
    }

    for (let i = 0; i < 35; i++) {
      let ang = noise(this.textureSeed + 200 + i * 7.3) * TWO_PI;
      let dist = noise(this.textureSeed + 200 + i * 11.1) * discR * 1.4;
      let sz = 0.5 + noise(this.textureSeed + 200 + i * 5.0) * 2.0;

      _cm(HSB, 360, 100, 100);
      let h = hue(this.col) + (noise(this.textureSeed + 200 + i * 2.0) - 0.5) * 30;
      let bri = 50 + noise(this.textureSeed + 200 + i * 3.0) * 45;
      _g.fill(h, 50, bri, 100 + noise(this.textureSeed + 200 + i * 1.3) * 100);
      _cm(RGB, 255);

      _g.ellipse(cos(ang) * dist, sin(ang) * dist, sz, sz);
    }
  }

  // ── drawPetal ─────────────────────────────────────────────────────────
  drawPetal(angle, r, isShadow, petalIdx, widthScale) {
    let outerR =
      r * (0.84 + noise(this.textureSeed + angle * 5.3 + petalIdx * 0.7) * 0.32);
    let halfW = outerR * this.sideRatio * this.sideJitter * 0.50 * widthScale;
    let asymm =
      (noise(this.textureSeed + angle * 9.1 + petalIdx) - 0.5) * 0.55;
    let tipCurl =
      (noise(this.textureSeed + petalIdx * 13.7) - 0.5) *
      halfW * this.curlIntensity;

    let ox = isShadow ? 1.8 : 0;
    let oy = isShadow ? 1.8 : 0;

    _g.push();
    _g.translate(ox, oy);
    _g.rotate(angle);

    let wR = halfW * (1.0 + asymm);
    let wL = halfW * (1.0 - asymm);

    // Per-petal colour tint
    let petalCol = this.col;
    let petalShadow = this.shadowCol;
    if (!isShadow) {
      _cm(HSB, 360, 100, 100);
      let hShift = (noise(this.textureSeed + petalIdx * 4.3) - 0.5) * 42;
      let sShift = (noise(this.textureSeed + petalIdx * 6.1) - 0.5) * 28;
      let bShift = (noise(this.textureSeed + petalIdx * 8.7) - 0.5) * 22;
      petalCol = color(
        hue(this.col) + hShift,
        constrain(saturation(this.col) + sShift, 8, 95),
        constrain(brightness(this.col) + bShift, 35, 96)
      );
      petalShadow = color(
        hue(petalCol),
        saturation(petalCol) * 0.9,
        brightness(petalCol) * 0.46
      );
      _cm(RGB, 255);
    }

    if (isShadow) {
      _cm(HSB, 360, 100, 100);
      _g.fill(hue(petalShadow), saturation(petalShadow), brightness(petalShadow), 45);
      _cm(RGB, 255);
      _g.noStroke();
    } else {
      _g.fill(petalCol);
      if (this.cleanExportMode) {
        _cm(HSB, 360, 100, 100);
        _g.stroke(hue(this.outlineCol), saturation(this.outlineCol), brightness(this.outlineCol), 180);
        _cm(RGB, 255);
        _g.strokeWeight(this.isMain ? 0.8 : 0.55);
      } else {
        _cm(HSB, 360, 100, 100);
        _g.stroke(hue(this.outlineCol), saturation(this.outlineCol), brightness(this.outlineCol), this.outlineAlpha);
        _cm(RGB, 255);
        _g.strokeWeight(this.outlineWeight);
      }
    }

    // Petal shape
    _g.beginShape();
    _g.vertex(0, 0);
    _g.bezierVertex(
      outerR * 0.10, wR * 0.45,
      outerR * 0.24, wR * 0.90,
      outerR * 0.40, wR
    );
    _g.bezierVertex(
      outerR * 0.58, wR * 0.90,
      outerR * 0.84, wR * 0.30,
      outerR, tipCurl
    );
    _g.bezierVertex(
      outerR * 0.84, -wL * 0.30,
      outerR * 0.58, -wL * 0.90,
      outerR * 0.40, -wL
    );
    _g.bezierVertex(
      outerR * 0.24, -wL * 0.90,
      outerR * 0.10, -wL * 0.45,
      0, 0
    );
    _g.endShape(CLOSE);

    // Texture and vein details (colour pass only)
    if (!isShadow) {
      // Sketchy double outline (screen only)
      if (!this.cleanExportMode) {
        _g.noFill();
        let dOff =
          (this.isMain ? 1.0 : 0.6) *
          (noise(this.textureSeed + petalIdx * 2.2) * 0.5 + 0.5);
        _cm(HSB, 360, 100, 100);
        _g.stroke(
          hue(this.outlineCol), saturation(this.outlineCol),
          brightness(this.outlineCol), this.outlineAlpha * 0.3
        );
        _cm(RGB, 255);
        _g.strokeWeight(this.outlineWeight * 0.5);
        _g.beginShape();
        _g.vertex(dOff, dOff);
        _g.bezierVertex(
          outerR * 0.10 + dOff, wR * 0.45 + dOff,
          outerR * 0.24 + dOff, wR * 0.90 + dOff,
          outerR * 0.40 + dOff, wR + dOff
        );
        _g.bezierVertex(
          outerR * 0.58 + dOff, wR * 0.90 + dOff,
          outerR * 0.84 + dOff, wR * 0.30 + dOff,
          outerR + dOff, tipCurl + dOff
        );
        _g.bezierVertex(
          outerR * 0.84 + dOff, -wL * 0.30 + dOff,
          outerR * 0.58 + dOff, -wL * 0.90 + dOff,
          outerR * 0.40 + dOff, -wL + dOff
        );
        _g.bezierVertex(
          outerR * 0.24 + dOff, -wL * 0.90 + dOff,
          outerR * 0.10 + dOff, -wL * 0.45 + dOff,
          dOff, dOff
        );
        _g.endShape(CLOSE);
      }

      // Centre vein
      _cm(HSB, 360, 100, 100);
      _g.stroke(
        hue(this.outlineCol), saturation(this.outlineCol),
        brightness(this.outlineCol), this.outlineAlpha * 0.55
      );
      _cm(RGB, 255);
      _g.strokeWeight(this.outlineWeight * 0.7);
      let w1 = (noise(this.textureSeed + angle * 3.0) - 0.5) * halfW * 0.20;
      let w2 = (noise(this.textureSeed + angle * 3.0 + 10) - 0.5) * halfW * 0.15;
      _g.noFill();
      _g.bezier(
        outerR * 0.04, 0,
        outerR * 0.28, w1,
        outerR * 0.58, w2,
        outerR * 0.91, tipCurl * 0.7
      );

      // Side veins
      let nVeins = 3 + int(noise(this.textureSeed + angle * 2.0) * 3);
      for (let v = 0; v < nVeins; v++) {
        let t = 0.18 + v * (0.65 / nVeins);
        let vx = outerR * t;
        let vLenR = wR * (0.55 - v * 0.03) * (0.7 + noise(this.textureSeed + angle * 3.0 + v * 7.0) * 0.6);
        let vLenL = wL * (0.55 - v * 0.03) * (0.7 + noise(this.textureSeed + angle * 3.0 + v * 11.0) * 0.6);
        let vAng = radians(28 + v * 7 + noise(this.textureSeed + v * 5.0) * 18);
        _cm(HSB, 360, 100, 100);
        _g.stroke(
          hue(this.outlineCol), saturation(this.outlineCol),
          brightness(this.outlineCol), 35 + noise(this.textureSeed + v * 3.3) * 45
        );
        _cm(RGB, 255);
        _g.strokeWeight(this.outlineWeight * 0.45);
        _g.noFill();
        let cvx = cos(vAng) * vLenR;
        let cvy = sin(vAng) * vLenR;
        _g.bezier(vx, 0, vx + cvx * 0.3, cvy * 0.15, vx + cvx * 0.7, cvy * 0.6, vx + cvx, cvy);
        let cvxL = cos(-vAng) * vLenL;
        let cvyL = sin(-vAng) * vLenL;
        _g.bezier(vx, 0, vx + cvxL * 0.3, cvyL * 0.15, vx + cvxL * 0.7, cvyL * 0.6, vx + cvxL, cvyL);
      }

      // Texture: hatching or stipple
      if (this.useStipple) {
        _g.noStroke();
        let nDots = int(outerR * 0.5 * this.hatchDensity);
        for (let d = 0; d < nDots; d++) {
          let dt = 0.10 + noise(this.textureSeed + d * 1.3 + angle * 2.0) * 0.80;
          let dx = outerR * dt;
          let widthHere = halfW * sin(dt * PI) * 0.80;
          if (widthHere < 1) continue;
          let dy = (noise(this.textureSeed + d * 3.7 + angle * 4.0) - 0.5) * widthHere * 1.4;
          _cm(HSB, 360, 100, 100);
          _g.fill(
            hue(this.outlineCol), saturation(this.outlineCol),
            brightness(this.outlineCol), 25 + noise(this.textureSeed + d * 2.1) * 35
          );
          _cm(RGB, 255);
          let dotSz = 0.5 + noise(this.textureSeed + d * 4.1) * 1.2;
          _g.ellipse(dx, dy, dotSz, dotSz);
        }
      } else {
        // Hatching lines
        _cm(HSB, 360, 100, 100);
        _g.stroke(
          hue(this.outlineCol), saturation(this.outlineCol),
          brightness(this.outlineCol), 18 + this.hatchDensity * 12
        );
        _cm(RGB, 255);
        _g.strokeWeight(0.35);
        let hatchAng = radians(50 + noise(this.textureSeed + angle) * 40);
        let nHatch = int(outerR * (0.10 + this.hatchDensity * 0.35));
        for (let h = 0; h < nHatch; h++) {
          let ht = 0.10 + h * (0.80 / max(1, nHatch));
          let hx = outerR * ht;
          let widthHere = halfW * sin(ht * PI) * 0.88;
          if (widthHere < 1) continue;
          let jx = (noise(this.textureSeed + h * 1.7 + angle * 4.0) - 0.5) * 4;
          let jy = (noise(this.textureSeed + h * 2.3 + angle * 5.0) - 0.5) * 3;
          let hLen = widthHere * (0.4 + noise(this.textureSeed + h * 0.9) * 0.6);
          _g.line(
            hx + jx, -hLen * 0.5 + jy,
            hx + jx + cos(hatchAng) * hLen * 0.35, hLen * 0.5 + jy
          );
        }

        // Cross-hatch
        if (this.hatchDensity > 0.35) {
          _cm(HSB, 360, 100, 100);
          _g.stroke(
            hue(this.outlineCol), saturation(this.outlineCol),
            brightness(this.outlineCol), 12 + this.hatchDensity * 8
          );
          _cm(RGB, 255);
          let crossAng = hatchAng + radians(65);
          let nCross = int(3 + this.hatchDensity * 4);
          for (let h = 0; h < nCross; h++) {
            let ht = 0.08 + h * 0.10;
            let hx = outerR * ht;
            let widthHere = halfW * sin(ht * PI) * 0.65;
            if (widthHere < 1) continue;
            let jx = (noise(this.textureSeed + h * 5.1 + angle * 2.0) - 0.5) * 3;
            _g.line(
              hx + jx, -widthHere * 0.35,
              hx + jx + cos(crossAng) * widthHere * 0.35, widthHere * 0.35
            );
          }
        }
      }
    }

    _g.pop();
  }
}
