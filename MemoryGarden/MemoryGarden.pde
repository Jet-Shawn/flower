// MemoryGarden — Processing 4
// ---------------------------------------------------------------------------
// Reads data/garden.json (generated via LLM — see TUTORIAL.md) and draws an
// animated origami memory garden.  Generate garden.json first, then press Play (▶).
//
// Layout per cluster:
//   [THEME]
//   [My full memory text]   ← anchored directly above the flower head
//       🌸
// ---------------------------------------------------------------------------

ArrayList<FlowerCluster> clusters;
String centerName = "";
JSONArray allClusters;
int[] shuffleQueue;
int   queuePos = 0;

final float TOP_MARGIN = 46;
final float CELL_W     = 800;   // single column
final float ROW_H      = 754;   // full height minus header (800 − 46)

// ── Setup ───────────────────────────────────────────────────────────────────
void setup() {
  size(800, 800);
  smooth(4);

  JSONObject root = loadJSONObject("garden.json");
  centerName  = root.getString("center_name");
  allClusters = root.getJSONArray("all_clusters");

  if (allClusters != null && allClusters.size() >= 1) {
    buildShuffleQueue();
    loadCurrentPage();
  }
}

// ── Draw ────────────────────────────────────────────────────────────────────
void draw() {
  for (FlowerCluster fc : clusters) fc.update();
  drawScene();
}

void drawScene() {
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

  // Memory counter (top-right)
  noStroke();
  fill(175, 155, 130, 180);
  textSize(12);
  textAlign(RIGHT, BASELINE);
  int total = (allClusters != null) ? allClusters.size() : 1;
  int current = queuePos + 1;
  text(current + " / " + total + "   •   R to shuffle   •   P to save flower (with + without stem)", width - 18, 30);

  for (FlowerCluster fc : clusters) fc.draw();

}

// ── Keyboard ─────────────────────────────────────────────────────────────────
void keyPressed() {
  if (key == 'r' || key == 'R') shuffleGarden();
  if (key == 'p' || key == 'P') saveFlowerHead();
}

// Saves two images: one with just the flower head, one with stem included.
void saveFlowerHead() {
  int SZ = 2048;
  Flower f = clusters.get(0).main;
  float sf = (SZ * 0.40) / (f.baseRadius * f.radiusJitter);
  String tag = nf(frameCount, 4);

  // ── Image 1: head only (no stem) ────────────────────────────────────────
  PGraphics pgHead = createGraphics(SZ, SZ, JAVA2D);
  pgHead.beginDraw();
  pgHead.background(248, 244, 235);
  pgHead.translate(SZ * 0.5, SZ * 0.5);
  pgHead.scale(sf);
  pgHead.smooth(8);

  PGraphics prev = g;
  g = pgHead;
  f.drawHeadOnly();
  g = prev;

  pgHead.endDraw();
  String headFile = "flower-head-" + tag + ".png";
  pgHead.save(headFile);
  println("Saved " + headFile + "  (" + SZ + "x" + SZ + " px, head only)");

  // ── Image 2: with stem ───────────────────────────────────────────────────
  float totalH_raw = f.stemHeight + f.baseRadius * f.radiusJitter * 1.4;
  float sfStem     = (SZ * 0.88) / totalH_raw;

  PGraphics pgStem = createGraphics(SZ, SZ, JAVA2D);
  pgStem.beginDraw();
  pgStem.background(248, 244, 235);
  pgStem.smooth(8);
  float baseX = SZ * 0.5;
  float baseY = SZ - (SZ * 0.08);
  pgStem.translate(baseX, baseY);
  pgStem.scale(sfStem);

  g = pgStem;
  f.drawWithStem();
  g = prev;

  pgStem.endDraw();
  String stemFile = "flower-stem-" + tag + ".png";
  pgStem.save(stemFile);
  println("Saved " + stemFile + "  (" + SZ + "x" + SZ + " px, with stem)");
}

// Advances the queue by 2 and loads the next pair.
// Rebuilds (reshuffles) the queue when the last pair has been shown.
void shuffleGarden() {
  if (allClusters == null) {
    println("Shuffle unavailable: re-run script_one.py to generate all_clusters.");
    return;
  }
  queuePos += 1;
  if (queuePos >= shuffleQueue.length) buildShuffleQueue();
  loadCurrentPage();
}

// Fisher-Yates shuffle of all cluster indices; resets queuePos to 0.
void buildShuffleQueue() {
  int n = allClusters.size();
  shuffleQueue = new int[n];
  for (int i = 0; i < n; i++) shuffleQueue[i] = i;
  for (int i = n - 1; i > 0; i--) {
    int j = (int) random(i + 1);
    int tmp = shuffleQueue[i]; shuffleQueue[i] = shuffleQueue[j]; shuffleQueue[j] = tmp;
  }
  queuePos = 0;
}

// Creates one FlowerCluster for the current queue position.
void loadCurrentPage() {
  clusters = new ArrayList<FlowerCluster>();
  int qi = shuffleQueue[queuePos];
  clusters.add(new FlowerCluster(allClusters.getJSONObject(qi), 0, TOP_MARGIN, 0));
}

float wrapHue(float h) {
  return (h % 360 + 360) % 360;
}

float blendHue(float a, float b, float amt) {
  float delta = ((b - a + 540) % 360) - 180;
  return wrapHue(a + delta * amt);
}

float semanticHue(float valenceNorm, float impact, float togetherness, float motion, float lengthNorm) {
  float coolAnchor = 210 + motion * 20 - impact * 18;
  float warmAnchor = 28 + impact * 34 - motion * 10;
  float socialAnchor = 122 + togetherness * 36 - lengthNorm * 14;
  float dreamyAnchor = 286 + motion * 34 + impact * 10;
  float vividAnchor = 342 + lengthNorm * 32 - togetherness * 14;

  float sadBase = blendHue(coolAnchor, dreamyAnchor, 0.35 + motion * 0.25);
  float happyBase = blendHue(socialAnchor, warmAnchor, 0.30 + impact * 0.35);
  float neutralBase = blendHue(vividAnchor, socialAnchor, 0.45 + togetherness * 0.20);

  float h = blendHue(sadBase, happyBase, pow(valenceNorm, 0.78));
  h = blendHue(h, neutralBase, 0.16 + lengthNorm * 0.14);

  float featureSpin = impact * 80 + togetherness * 55 + motion * 95 + lengthNorm * 120;
  h = wrapHue(h + featureSpin);

  float accentRoll = random(1);
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

color buildSemanticFlowerColor(float valence, float impact, float togetherness, float motion, float lengthNorm) {
  float valenceNorm = constrain((valence + 1.0) * 0.5, 0, 1);

  float h = semanticHue(valenceNorm, impact, togetherness, motion, lengthNorm);

  float satJitter = random(-16, 16);
  float brightJitter = random(-14, 14);
  float paletteLift = random(-12, 18);

  float sadSat = 10 + togetherness * 14 + lengthNorm * 12;
  float happySat = 58 + impact * 22 + togetherness * 12 + lengthNorm * 18;
  float altSat = 34 + motion * 18 + lengthNorm * 22;
  float s = lerp(sadSat, happySat, pow(valenceNorm, 0.70));
  s = lerp(s, altSat, random(0.12, 0.38));
  s += map(impact, 0, 1, -10, 10) - motion * 8 + satJitter + paletteLift;

  float sadBright = 38 + lengthNorm * 16 + impact * 6;
  float happyBright = 62 + impact * 18 + lengthNorm * 16;
  float altBright = 54 + togetherness * 10 + random(-8, 10);
  float b = lerp(sadBright, happyBright, pow(valenceNorm, 0.82));
  b = lerp(b, altBright, random(0.10, 0.34));
  b += togetherness * 6 - motion * 5 + brightJitter;

  colorMode(HSB, 360, 100, 100);
  return color(wrapHue(h),
               constrain(s, 10, 98),
               constrain(b, 26, 98));
}


// ── FlowerCluster ────────────────────────────────────────────────────────────
// Manages one "cluster": your memory and its flower.
// You probably don't need to change anything in here — it handles layout and
// text rendering. The interesting stuff is in the Flower class below.
class FlowerCluster {
  Flower   main;
  float    cellLeft, cellTop;
  String   theme;
  int      clusterIdx;

  FlowerCluster(JSONObject data, float cellLeft, float cellTop, int idx) {
    this.cellLeft   = cellLeft;
    this.cellTop    = cellTop;
    this.clusterIdx = idx;
    this.theme = data.getString("theme", "Memory");

    float cx        = cellLeft + CELL_W * 0.5;
    float mainStemY = cellTop  + 560;  // ← vertical position of stem base; raise/lower to reposition flower

    main = new Flower(data.getJSONObject("center"), cx, mainStemY, true, idx * 10);
  }

  void update() {
    main.update();
  }

  void draw() {
    float mainEb    = sin(main.bloom * HALF_PI);
    float textAlpha = constrain(map(mainEb, 0.1, 0.7, 0, 255), 0, 255);

    // ── 1 & 2. Theme + main memory text, anchored directly above the flower head
    // Compute flower-head y at full bloom (un-scaled), then place text just above petals.
    float textBoxBot = cellTop + 310;  // fixed vertical anchor per cell
    float cx         = cellLeft + CELL_W * 0.5;
    float maxW       = min(CELL_W - 80, 560);

    noStroke();

    // --- MAIN TEXT (fixed box, anchored correctly) ---
    float maxTextH = 110;  // safe height for wrapping

    textSize(20);
    textAlign(CENTER, TOP);

    // Anchor box ABOVE flower
    float textTop = textBoxBot - maxTextH;

    fill(52, 46, 40, textAlpha);
    text(main.memory, cx - maxW/2, textTop, maxW, maxTextH);

    // --- THEME ---
    textSize(26);
    textAlign(CENTER, TOP);
    fill(155, 115, 75, textAlpha);
    text("◆  " + theme.toUpperCase() + "  ◆", cx, textTop - 50);

    // ── 3. Flower ─────────────────────────────────────────────────────────
    main.draw();
  }
}


// ── Flower ───────────────────────────────────────────────────────────────────
// THIS IS THE MAIN CLASS TO CHANGE.
//
// Each Flower represents one memory. (x, y) is the stem base at ground level.
// The stem grows upward (in screen space, upward = negative y).
//
// The class has two parts you'll work in:
//
//   1. The CONSTRUCTOR (Flower(...) below) — runs once when the flower is created.
//      This is where the five feature values get turned into visual properties.
//      Change the mappings here to change what each feature means visually.
//
//   2. The DRAW METHOD (void draw()) — runs every frame.
//      This is where the actual shape is drawn. Replace or rewrite this to
//      change what the visual object looks like entirely.
//
// The five features are available as local variables in the constructor,
// and valence is also stored as a field for use in draw() and drawPetal():
//   valence          — -1 (very sad) → 1 (very happy)
//   impact           — 0 (calm language) → 1 (emotionally intense)
//   tog              — 0 (solitary memory) → 1 (very social)
//   motion           — 0 (still) → 1 (full of movement)
//   lengthNorm       — 0 (short) → 1 (long / detailed)
//
// Other useful fields available in draw():
//   bloom        — grows from 0 to 1 as the flower animates in; multiply things
//                  by bloom (or eb, the eased version) to animate them growing - what might your version of bloom be?
//   x, y         — screen position of the stem base
// ---------------------------------------------------------------------------

class Flower {
  float   x, y;
  float   baseRadius;   // max petal reach in pixels
  float   sideRatio;    // controls petal shape: 0.24 = spiky, 0.58 = broad
  int     numPetals;
  float   stemHeight;
  color   col, shadowCol, centerCol;
  float   swaySpeed, swayPhase;
  float   valence;
  float   tiltDir;
  float   postureTilt;
  float   stemBend;
  float   headNod;
  float   radiusJitter;
  float   sideJitter;
  float   petalSpreadJitter;
  float   textureSeed;
  boolean isMain;
  String  memory;
  float   bloom = 0.0;
  int     bloomDelay;
  int     startFrame;

  // Per-flower style variation fields
  float   outlineWeight;    // stroke weight for petal outlines
  float   outlineAlpha;     // opacity of petal outlines
  color   outlineCol;       // tinted outline colour (dark version of flower hue)
  color   stemCol;          // stem colour influenced by flower hue
  float   hatchDensity;     // 0 = minimal/clean, 1 = dense hatching
  boolean useStipple;       // true = stipple dots instead of hatching
  float   curlIntensity;    // how much petal tips curl
  float   spatterDensity;   // 0 = almost none, 1 = heavy cloud
  float   centreScale;      // relative size of the centre disc
  float   ringSpread;       // how spread apart the petal rings are
  float   petalLenVariance; // how much individual petal lengths vary within a ring
  float   angularChaos;     // extra angular randomness per ring
  int     ringCount;        // number of petal rings (2-4) for multi-ring blooms
  float   petalWidthWarp;   // per-flower warp on petal width
  boolean cleanExportMode;  // removes sketch-outline strokes in PNG exports

  // ── Constructor ───────────────────────────────────────────────────────────
  // Runs once per flower when the sketch loads or shuffles.
  // This is where you decide what the five features mean visually.
  // Most feature values are between 0 and 1; valence spans -1 to 1.
  // Use map() to translate them into whatever range makes sense visually.

  Flower(JSONObject data, float x, float y, boolean isMain, int bloomDelay) {
    this.x = x;  this.y = y;
    this.isMain     = isMain;
    this.bloomDelay = bloomDelay;
    this.startFrame = frameCount;

    memory = data.getString("memory");

    // The five feature values — these drive everything below.
    JSONObject f   = data.getJSONObject("features");
    valence  = f.getFloat("valence");                       // -1 = sad, 1 = happy
    float impact     = f.getFloat("impact");               // 0 = calm, 1 = intense
    float tog        = f.getFloat("togetherness");         // 0 = alone, 1 = social
    float motion     = f.getFloat("motion");               // 0 = still, 1 = full of movement
    float lengthNorm = f.getFloat("length");               // 0 = short, 1 = long / detailed
    float valenceNorm = constrain((valence + 1.0) * 0.5, 0, 1);

    // ── Colour ───────────────────────────────────────────────────────────
    // Sadder memories drift toward muted blue tones; happier ones push into
    // greener, more vivid colours. Other features widen the palette and
    // small random jitter keeps each regeneration a little unique.
    colorMode(HSB, 360, 100, 100);
    col = buildSemanticFlowerColor(valence, impact, tog, motion, lengthNorm);
    float h = hue(col);
    float s = saturation(col);
    float b = brightness(col);

    shadowCol = color(h, s * 0.90, b * 0.46);    // dark shadow for paper-cut depth
    centerCol = color(h, s * 0.24, min(98, b + 18)); // bright pale centre dot
    colorMode(RGB, 255);

    // ── Size and shape ────────────────────────────────────────────────────
    // impact → petal reach (bigger = more intense) AND shape (spikier = more intense)
    // → Change the map() ranges to make flowers bigger/smaller overall,
    //   or decouple size from shape by using a different feature for each.
    baseRadius = isMain ? map(impact, 0, 1, 41.6, 96.2)
                        : map(impact, 0, 1, 18.2, 49.4);
    float impactShape  = map(impact, 0, 1, 0.72, 0.18);  // impact: broad → spiky
    float valenceShape = map(valenceNorm, 0, 1, 0.18, 1.05); // valence: spiky → very round
    sideRatio = lerp(impactShape, valenceShape, 0.70);   // valence dominates

    // ── Petal count ───────────────────────────────────────────────────────
    // togetherness → number of petals (more social = more petals)
    // → Change the 4/13 range to allow fewer or more petals.
    numPetals  = max(2, (int) map(tog, 0, 1, 3, 10) + (int) random(-1, 2));
    if (!isMain) numPetals = max(3, numPetals + (int) random(-3, 3));

    // ── Sway speed ────────────────────────────────────────────────────────
    // motion → quicker sway for lively memories; calmer for still ones.
    swaySpeed  = map(motion, 0, 1, 0.008, 0.024);
    swayPhase  = random(TWO_PI);

    // ── Stem height ───────────────────────────────────────────────────────
    // length → taller stems for longer, more detailed memories
    // → Change the pixel ranges if you want shorter/taller stems.
    stemHeight = isMain ? map(lengthNorm, 0, 1, 143, 260) * random(0.88, 1.14)
                        : map(lengthNorm, 0, 1, 91, 188.5) * random(0.72, 1.32);

    // ── Droop (valence → posture) ─────────────────────────────────────────
    // Sad flowers droop; very sad ones hang their heads back down.
    // tiltDir is randomly left or right so not all sad flowers lean the same way.
    // → Change the radians values to adjust how much the head nods.
    tiltDir     = random(1) < 0.5 ? -1 : 1;
    postureTilt = tiltDir * map(valence, -1, 1, radians(10), radians(-4));
    stemBend    = tiltDir * (map(valence, -1, 1, 28, 5) + random(-4, 4));
    headNod     = map(valence, -1, 1, radians(52), radians(-8));

    // Random variation so flowers look distinctly different each time.
    radiusJitter      = isMain ? random(0.88, 1.15) : random(0.65, 1.40);
    sideJitter        = isMain ? random(0.80, 1.20) : random(0.60, 1.40);
    petalSpreadJitter = isMain ? random(-radians(8), radians(8))
                               : random(-radians(18), radians(18));
    textureSeed       = random(1000);

    // ── Per-flower style variation ──────────────────────────────────────────
    // These make each flower visually distinct beyond just size/count/colour.

    // Outline: intense memories get bold outlines, calm ones are whisper-thin
    outlineWeight = isMain ? map(impact, 0, 1, 0.5, 2.0) : map(impact, 0, 1, 0.3, 1.3);
    outlineAlpha  = map(impact, 0, 1, 80, 210);

    // Outline & vein colour: dark tint of the flower's own hue (not universal black)
    colorMode(HSB, 360, 100, 100);
    outlineCol = color(hue(col), constrain(saturation(col) * 0.6, 15, 70), 15 + impact * 10);
    // Stem colour: blended between olive green and flower hue
    float stemHue = lerp(115, hue(col), 0.35 + valence * 0.2);
    stemCol = color(stemHue, constrain(35 + saturation(col) * 0.3, 20, 60), 45 + lengthNorm * 15);
    colorMode(RGB, 255);

    // Hatching: movement adds surface energy; calm memories stay cleaner
    hatchDensity = motion * 0.7 + impact * 0.3;
    // ~20% of flowers use stipple dots instead of line hatching
    useStipple = (noise(textureSeed * 0.37) < 0.20);

    // Tip curl: longer memories get more dramatic curl at the tip
    curlIntensity = map(lengthNorm, 0, 1, 0.1, 1.0) * (0.5 + noise(textureSeed * 0.61) * 1.0);

    // Spatter: varies widely per flower
    spatterDensity = noise(textureSeed * 0.43) * 0.6 + impact * 0.4;

    // Centre size: impact drives prominence
    centreScale = map(impact, 0, 1, 0.7, 1.4) * (0.85 + noise(textureSeed * 0.29) * 0.3);

    // Ring spread: togetherness = tighter rings (social = cohesive), solitary = spread out
    ringSpread = map(tog, 0, 1, 1.3, 0.8) * (0.85 + noise(textureSeed * 0.51) * 0.3);

    // Per-flower structural randomness — makes each flower unique
    petalLenVariance = 0.25 + random(0.35);   // 0.25–0.60: how much petal lengths differ within a ring
    angularChaos     = 0.3 + random(0.7);     // 0.3–1.0: extra angular wobble
    ringCount        = 2 + (int) random(3);   // 2–4 rings for multi-petal flowers
    petalWidthWarp   = random(0.75, 1.35);    // warps petal width per flower
  }

  // ── Update ────────────────────────────────────────────────────────────────
  void update() {
    if (frameCount > startFrame + bloomDelay) bloom = min(bloom + 0.016, 1.0);
  }

  // ── drawHeadOnly ──────────────────────────────────────────────────────────
  // Draws just the flower head (petals + centre) centred at (0,0).
  // Used by saveFlowerHead() — no stem, no positioning transforms.
  void drawHeadOnly() {
    float eb = sin(bloom * HALF_PI);
    if (eb < 0.02) eb = 1.0;
    float r = baseRadius * radiusJitter * eb;
    cleanExportMode = true;
    drawAllPetals(r, eb);
    cleanExportMode = false;
    drawSpatter(r, eb, 0, 0);
  }

  // ── drawWithStem ──────────────────────────────────────────────────────────
  // Draws stem + flower head centred on the current origin (0,0 = stem base).
  // Used by saveFlowerHead() for the "with stem" export — no text, no UI chrome.
  void drawWithStem() {
    float eb = sin(bloom * HALF_PI);
    if (eb < 0.02) eb = 1.0;  // fully open if not yet bloomed

    float r    = baseRadius * radiusJitter * eb;
    float sh   = stemHeight * eb;
    float bend = stemBend * eb;

    // Stem
    stroke(stemCol, 200);
    strokeWeight(isMain ? 2.3 : 1.4);
    noFill();
    bezier(0, 0,
           0, -sh * 0.88,
           bend, -sh * 0.96,
           bend, -sh);
    noStroke();

    // Flower head
    pushMatrix();
    translate(bend, -sh);
    rotate(postureTilt + headNod * eb);
    cleanExportMode = true;
    drawAllPetals(r, eb);
    cleanExportMode = false;
    popMatrix();
    drawSpatter(r, eb, bend, -sh);
  }

  // ── Draw ──────────────────────────────────────────────────────────────────
  // Runs every frame. Draws the stem and flower head at position (x, y).
  //
  // Key variables available here:
  //   eb          — bloom eased to a curve (0 → 1); multiply sizes by this
  //                 to make things grow in smoothly
  //   sway        — oscillates between -0.22 and +0.22 each frame
  //   sh          — current stem height (grows with bloom)
  //   r           — current petal radius (grows with bloom)
  //   col         — the flower's colour (set in constructor)
  //   isMain      — true for the featured memory
  //
  // → To replace the flower shape entirely: keep the stem bezier, then
  //   replace everything after "translate(bend + stemSway, -sh + headDropY)"
  //   with your own drawing code. At that point (0,0) is the flower head.
  // → To remove petals and draw something else from scratch, delete the
  //   drawPetal() calls and write new shapes using Processing's drawing
  //   functions (rect, ellipse, beginShape/vertex, etc.)
  void draw() {
    float eb = sin(bloom * HALF_PI);   // eased bloom: starts slow, ends smooth
    if (eb < 0.02) return;

    float sway     = sin(frameCount * swaySpeed + swayPhase) * 0.22 * eb;
    float r        = baseRadius * radiusJitter * eb;
    float sh       = stemHeight * eb;
    float lean     = postureTilt * eb + sway * 0.80;
    float bend     = stemBend * eb;
    float stemSway = sway * sh * 0.55;
    // Sad flowers droop their head back down toward ground level
    float sadness   = constrain((-valence + 1.0) * 0.5, 0, 1);
    float headDropY = sh * pow(sadness, 1.6) * 0.72;

    pushMatrix();
    translate(x, y);

    // ── Stem ──────────────────────────────────────────────────────────────
    // A bezier curve from the ground (0,0) up to the flower head.
    // The control points are placed high so the stem stays straight and
    // only bends near the top.
    // → Change stroke() colour/weight to restyle the stem.
    // → Replace bezier() with a straight line() for a rigid stem.
    stroke(stemCol, 200 * eb);
    strokeWeight(isMain ? 2.3 : 1.4);
    noFill();
    bezier(0, 0,
           stemSway * 0.01, -sh * 0.88,
           bend + stemSway * 0.92, -sh * 0.96 + headDropY * 0.6,
           bend + stemSway, -sh + headDropY);
    noStroke();

    // ── Flower head ───────────────────────────────────────────────────────
    // Everything below is drawn relative to the flower head position.
    // (0, 0) here = the centre of the flower head.
    translate(bend + stemSway, -sh + headDropY);
    rotate(lean + headNod * eb);

    drawAllPetals(r, eb);

    popMatrix();

    // Spatter drawn in its own coordinate space — follows the flower head
    // position loosely but does NOT inherit sway rotation, so particles
    // feel like they float independently.
    // Anchor spatter at the resting head position — no stemSway — so particles
    // don't rock with the flower. They drift independently in drawSpatter.
    float headX = x + bend + stemSway * 0.55;
    float headY = y + (-sh + headDropY);
    drawSpatter(r, eb, headX, headY);
  }

  // ── drawAllPetals ────────────────────────────────────────────────────────
  // Low petal counts (<=5) get a sparse, wild single-ring look with long
  // thin petals and a big centre. Higher counts get the full 3-ring bloom.
  void drawAllPetals(float r, float eb) {

    if (numPetals <= 5) {
      // --- Sparse wildflower style ---
      // Single ring, elongated petals, heavy angular randomness
      int n = numPetals + (int)(noise(textureSeed * 0.44) * 2);
      float sparseR   = r * (1.15 + noise(textureSeed * 0.19) * 0.35);
      float sparseOff = noise(textureSeed * 0.31) * TWO_PI;
      drawRing(n, sparseR, sparseOff, 0.80 + noise(textureSeed * 0.57) * 0.4, 0, eb, 0.40 + noise(textureSeed * 0.63) * 0.30);

      // Maybe 1-3 tiny accent petals tucked near the centre
      int accent = 1 + (int)(noise(textureSeed * 0.77) * 3);
      float accentOff = noise(textureSeed * 0.55) * TWO_PI;
      drawRing(accent, sparseR * (0.25 + noise(textureSeed * 0.83) * 0.20), accentOff, 1.0, 200, eb, 0.35 + noise(textureSeed * 0.71) * 0.30);

      // Proportionally larger centre
      drawCentre(r * 1.3 * centreScale, eb);
      return;
    }

    // --- Full multi-ring bloom (6+ petals) ---
    // ringCount (2-4) and ringSpread vary per flower for unique structures
    float[] ringRadii  = new float[ringCount];
    int[]   ringPetals = new int[ringCount];
    float[] ringOffs   = new float[ringCount];
    float[] ringJitter = new float[ringCount];
    float[] ringWidth  = new float[ringCount];

    for (int ri = 0; ri < ringCount; ri++) {
      float t = (float) ri / (ringCount - 1 + 0.001);  // 0 = outermost, 1 = innermost
      ringRadii[ri]  = r * (0.90 - t * 0.65 + ringSpread * 0.20 * (1 - t)) * (0.85 + noise(textureSeed * (0.31 + ri * 0.17)) * 0.30);
      ringPetals[ri] = max(3, numPetals + 3 - ri * 2 + (int)((noise(textureSeed * (0.53 + ri * 0.29)) - 0.5) * 4));
      ringOffs[ri]   = noise(textureSeed * (0.31 + ri * 0.36)) * TWO_PI;
      ringJitter[ri] = 0.35 + t * 0.25 + angularChaos * 0.15;
      ringWidth[ri]  = 0.7 + (1 - t) * 0.3 + noise(textureSeed * (0.44 + ri * 0.23)) * 0.25;
    }

    for (int ri = 0; ri < ringCount; ri++) {
      drawRing(ringPetals[ri], ringRadii[ri], ringOffs[ri], ringJitter[ri], ri * 50, eb, ringWidth[ri]);
    }

    drawCentre(r * centreScale, eb);
  }

  // Draws one ring of petals (shadow pass then colour pass).
  // widthScale < 1 makes petals thinner (used for sparse wildflower style).
  void drawRing(int n, float r, float baseOff, float jitterAmt, int seedOff, float eb, float widthScale) {
    for (int pass = 0; pass < 2; pass++) {
      boolean isShadow = (pass == 0);
      for (int i = 0; i < n; i++) {
        float angJitter = (noise(textureSeed + seedOff + i * 3.7) - 0.5) * jitterAmt * angularChaos;
        float a = baseOff + i * TWO_PI / n + angJitter + petalSpreadJitter;
        // Per-petal length variation driven by petalLenVariance
        float lenNoise = noise(textureSeed + seedOff + i * 1.1);
        float rJitter = r * (1.0 - petalLenVariance * 0.5 + lenNoise * petalLenVariance);
        float wScale = widthScale * petalWidthWarp * (0.8 + noise(textureSeed + seedOff + i * 5.3) * 0.4);
        drawPetal(a, rJitter, isShadow, seedOff + i, wScale);
      }
    }
  }

  // Warm-tone spatter dots that float independently around the flower head.
  // Drawn in screen space (cx, cy = flower head centre) so they don't
  // inherit sway/rotation. Each particle drifts on its own slow sine wave.
  void drawSpatter(float r, float eb, float cx, float cy) {
    noStroke();
    int nDots = (int)((isMain ? 55 : 30) * spatterDensity);
    for (int i = 0; i < nDots; i++) {
      // Base position (fixed per flower, seeded by textureSeed)
      float ang  = noise(textureSeed + i * 4.7) * TWO_PI;
      float dist = r * (0.25 + noise(textureSeed + i * 3.1) * 1.1);
      float bx = cos(ang) * dist;
      float by = sin(ang) * dist;

      // Independent gentle drift per particle
      float driftSpeed = 0.008 + noise(textureSeed + i * 1.3) * 0.014;
      float driftPhase = noise(textureSeed + i * 9.7) * TWO_PI;
      float driftAmp   = 1.5 + noise(textureSeed + i * 6.1) * 3.5;
      float dx = sin(frameCount * driftSpeed + driftPhase) * driftAmp;
      float dy = cos(frameCount * driftSpeed * 0.7 + driftPhase + 1.3) * driftAmp;

      float sz = 0.6 + noise(textureSeed + i * 6.3) * 3.2;

      // Colour: warm brown / rust / dark orange tinted by flower colour
      colorMode(HSB, 360, 100, 100);
      float h = hue(col) + (noise(textureSeed + i * 2.0) - 0.5) * 40;
      float s = 40 + noise(textureSeed + i * 8.0) * 50;
      float b = 30 + noise(textureSeed + i * 9.0) * 50;
      float a = (55 + noise(textureSeed + i * 1.5) * 140) * eb;
      fill(h, s, b, a);
      colorMode(RGB, 255);

      ellipse(cx + bx + dx, cy + by + dy, sz, sz);
    }
  }

  // Messy, organic flower centre with layered circles and speckles
  void drawCentre(float r, float eb) {
    float discR = (isMain ? 18 : 11) * eb;
    noStroke();

    // Layered dark circles for depth
    for (int layer = 3; layer >= 0; layer--) {
      float lr = discR * (0.6 + layer * 0.15);
      float lAlpha = 180 + layer * 20;
      colorMode(HSB, 360, 100, 100);
      fill(hue(col), saturation(col) * 0.3, 12 + layer * 5, lAlpha);
      colorMode(RGB, 255);
      float jx = (noise(textureSeed + layer * 3.3) - 0.5) * 3;
      float jy = (noise(textureSeed + layer * 5.5) - 0.5) * 3;
      ellipse(jx, jy, lr * 2, lr * 2);
    }

    // Dense speckle cloud around centre
    for (int i = 0; i < 35; i++) {
      float ang  = noise(textureSeed + 200 + i * 7.3) * TWO_PI;
      float dist = noise(textureSeed + 200 + i * 11.1) * discR * 1.4;
      float sz   = 0.5 + noise(textureSeed + 200 + i * 5.0) * 2.0;

      colorMode(HSB, 360, 100, 100);
      float h = hue(col) + (noise(textureSeed + 200 + i * 2.0) - 0.5) * 30;
      float bri = 50 + noise(textureSeed + 200 + i * 3.0) * 45;
      fill(h, 50, bri, 100 + noise(textureSeed + 200 + i * 1.3) * 100);
      colorMode(RGB, 255);

      ellipse(cos(ang) * dist, sin(ang) * dist, sz, sz);
    }
  }

  // ── drawPetal ─────────────────────────────────────────────────────────────
  // Elongated leaf petal with per-petal colour tint, sketchy double outline,
  // wobbly veins, and hatching. More abstract and hand-drawn.
  void drawPetal(float angle, float r, boolean isShadow, int petalIdx, float widthScale) {
    float outerR = r * (0.84 + noise(textureSeed + angle * 5.3 + petalIdx * 0.7) * 0.32);
    float halfW  = outerR * sideRatio * sideJitter * 0.50 * widthScale;
    float asymm  = (noise(textureSeed + angle * 9.1 + petalIdx) - 0.5) * 0.55;

    // Tip curl: scaled by per-flower curlIntensity
    float tipCurl = (noise(textureSeed + petalIdx * 13.7) - 0.5) * halfW * curlIntensity;

    float ox = isShadow ? 1.8 : 0;
    float oy = isShadow ? 1.8 : 0;

    pushMatrix();
    translate(ox, oy);
    rotate(angle);

    float wR = halfW * (1.0 + asymm);
    float wL = halfW * (1.0 - asymm);

    // -- Per-petal colour tint --
    color petalCol = col;
    color petalShadow = shadowCol;
    if (!isShadow) {
      colorMode(HSB, 360, 100, 100);
      float hShift = (noise(textureSeed + petalIdx * 4.3) - 0.5) * 42;
      float sShift = (noise(textureSeed + petalIdx * 6.1) - 0.5) * 28;
      float bShift = (noise(textureSeed + petalIdx * 8.7) - 0.5) * 22;
      petalCol = color(hue(col) + hShift,
                       constrain(saturation(col) + sShift, 8, 95),
                       constrain(brightness(col) + bShift, 35, 96));
      petalShadow = color(hue(petalCol), saturation(petalCol) * 0.9, brightness(petalCol) * 0.46);
      colorMode(RGB, 255);
    }

    if (isShadow) {
      fill(petalShadow, 45);
      noStroke();
    } else {
      fill(petalCol);
      if (cleanExportMode) {
        stroke(outlineCol, 180);
        strokeWeight(isMain ? 0.8 : 0.55);
      } else {
        stroke(outlineCol, outlineAlpha);
        strokeWeight(outlineWeight);
      }
    }

    // -- Petal shape with tip curl --
    beginShape();
    vertex(0, 0);
    bezierVertex(outerR * 0.10,  wR * 0.45,
                 outerR * 0.24,  wR * 0.90,
                 outerR * 0.40,  wR);
    bezierVertex(outerR * 0.58,  wR * 0.90,
                 outerR * 0.84,  wR * 0.30,
                 outerR,         tipCurl);
    bezierVertex(outerR * 0.84, -wL * 0.30,
                 outerR * 0.58, -wL * 0.90,
                 outerR * 0.40, -wL);
    bezierVertex(outerR * 0.24, -wL * 0.90,
                 outerR * 0.10, -wL * 0.45,
                 0, 0);
    endShape(CLOSE);

    // -- Texture and vein details (colour pass only) --
    if (!isShadow) {
      // Sketchy double outline stays on-screen, but is skipped in clean exports.
      if (!cleanExportMode) {
        noFill();
        float dOff = (isMain ? 1.0 : 0.6) * (noise(textureSeed + petalIdx * 2.2) * 0.5 + 0.5);
        stroke(outlineCol, outlineAlpha * 0.3);
        strokeWeight(outlineWeight * 0.5);
        beginShape();
        vertex(dOff, dOff);
        bezierVertex(outerR * 0.10 + dOff,  wR * 0.45 + dOff,
                     outerR * 0.24 + dOff,  wR * 0.90 + dOff,
                     outerR * 0.40 + dOff,  wR + dOff);
        bezierVertex(outerR * 0.58 + dOff,  wR * 0.90 + dOff,
                     outerR * 0.84 + dOff,  wR * 0.30 + dOff,
                     outerR + dOff,         tipCurl + dOff);
        bezierVertex(outerR * 0.84 + dOff, -wL * 0.30 + dOff,
                     outerR * 0.58 + dOff, -wL * 0.90 + dOff,
                     outerR * 0.40 + dOff, -wL + dOff);
        bezierVertex(outerR * 0.24 + dOff, -wL * 0.90 + dOff,
                     outerR * 0.10 + dOff, -wL * 0.45 + dOff,
                     dOff, dOff);
        endShape(CLOSE);
      }

      // -- Centre vein (wobbly bezier) --
      stroke(outlineCol, outlineAlpha * 0.55);
      strokeWeight(outlineWeight * 0.7);
      float w1 = (noise(textureSeed + angle * 3.0) - 0.5) * halfW * 0.20;
      float w2 = (noise(textureSeed + angle * 3.0 + 10) - 0.5) * halfW * 0.15;
      bezier(outerR * 0.04, 0,
             outerR * 0.28, w1,
             outerR * 0.58, w2,
             outerR * 0.91, tipCurl * 0.7);

      // -- Side veins (curved, not straight) --
      int nVeins = 3 + (int)(noise(textureSeed + angle * 2.0) * 3);
      for (int v = 0; v < nVeins; v++) {
        float t = 0.18 + v * (0.65 / nVeins);
        float vx = outerR * t;
        float vLenR = wR * (0.55 - v * 0.03) * (0.7 + noise(textureSeed + angle * 3.0 + v * 7.0) * 0.6);
        float vLenL = wL * (0.55 - v * 0.03) * (0.7 + noise(textureSeed + angle * 3.0 + v * 11.0) * 0.6);
        float vAng = radians(28 + v * 7 + noise(textureSeed + v * 5.0) * 18);
        stroke(outlineCol, 35 + noise(textureSeed + v * 3.3) * 45);
        strokeWeight(outlineWeight * 0.45);
        // Curved veins via bezier
        noFill();
        float cvx = cos(vAng) * vLenR;
        float cvy = sin(vAng) * vLenR;
        bezier(vx, 0,
               vx + cvx * 0.3, cvy * 0.15,
               vx + cvx * 0.7, cvy * 0.6,
               vx + cvx, cvy);
        float cvxL = cos(-vAng) * vLenL;
        float cvyL = sin(-vAng) * vLenL;
        bezier(vx, 0,
               vx + cvxL * 0.3, cvyL * 0.15,
               vx + cvxL * 0.7, cvyL * 0.6,
               vx + cvxL, cvyL);
      }

      // -- Texture: hatching lines OR stipple dots (per-flower style) --
      if (useStipple) {
        // Stipple dots instead of hatching
        noStroke();
        int nDots = (int)(outerR * 0.5 * hatchDensity);
        for (int d = 0; d < nDots; d++) {
          float dt = 0.10 + noise(textureSeed + d * 1.3 + angle * 2.0) * 0.80;
          float dx = outerR * dt;
          float widthHere = halfW * sin(dt * PI) * 0.80;
          if (widthHere < 1) continue;
          float dy = (noise(textureSeed + d * 3.7 + angle * 4.0) - 0.5) * widthHere * 1.4;
          fill(outlineCol, 25 + noise(textureSeed + d * 2.1) * 35);
          float dotSz = 0.5 + noise(textureSeed + d * 4.1) * 1.2;
          ellipse(dx, dy, dotSz, dotSz);
        }
      } else {
        // Hatching lines — density driven by hatchDensity
        stroke(outlineCol, 18 + hatchDensity * 12);
        strokeWeight(0.35);
        float hatchAng = radians(50 + noise(textureSeed + angle) * 40);
        int nHatch = (int)(outerR * (0.10 + hatchDensity * 0.35));
        for (int h = 0; h < nHatch; h++) {
          float ht = 0.10 + h * (0.80 / max(1, nHatch));
          float hx = outerR * ht;
          float widthHere = halfW * sin(ht * PI) * 0.88;
          if (widthHere < 1) continue;
          float jx = (noise(textureSeed + h * 1.7 + angle * 4.0) - 0.5) * 4;
          float jy = (noise(textureSeed + h * 2.3 + angle * 5.0) - 0.5) * 3;
          float hLen = widthHere * (0.4 + noise(textureSeed + h * 0.9) * 0.6);
          line(hx + jx, -hLen * 0.5 + jy,
               hx + jx + cos(hatchAng) * hLen * 0.35, hLen * 0.5 + jy);
        }

        // Cross-hatch near base (only if dense enough)
        if (hatchDensity > 0.35) {
          stroke(outlineCol, 12 + hatchDensity * 8);
          float crossAng = hatchAng + radians(65);
          int nCross = (int)(3 + hatchDensity * 4);
          for (int h = 0; h < nCross; h++) {
            float ht = 0.08 + h * 0.10;
            float hx = outerR * ht;
            float widthHere = halfW * sin(ht * PI) * 0.65;
            if (widthHere < 1) continue;
            float jx = (noise(textureSeed + h * 5.1 + angle * 2.0) - 0.5) * 3;
            line(hx + jx, -widthHere * 0.35,
                 hx + jx + cos(crossAng) * widthHere * 0.35, widthHere * 0.35);
          }
        }
      }
    }

    popMatrix();
  }
}
