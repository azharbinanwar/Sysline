/* Sysline landing visuals. Every scene is drawn once, at device resolution, and
   then left alone — the page shows a still frame of the app, not a loop. The
   history range chips are the only thing a visitor can change. */

"use strict";

const $ = (id) => document.getElementById(id);

// The app's own chart colors: Theme.down / Theme.up. Green is deepened one step
// from #30D158 so it holds up against this darker surface.
const DOWN = "#0A84FF";
const DOWN_HI = "#4EA6FF";
const UP = "#26A65B";
const GRID = "rgba(150,160,220,0.13)";
const DIM = "#5C6480";

/* Catmull-Rom through every point, as Swift Charts draws it in the app
   (.interpolationMethod(.catmullRom)). */
function smoothPath(context, pts) {
  context.beginPath();
  if (!pts.length) return;
  context.moveTo(pts[0][0], pts[0][1]);
  for (let i = 0; i < pts.length - 1; i++) {
    const p0 = pts[i - 1] || pts[i];
    const p1 = pts[i];
    const p2 = pts[i + 1];
    const p3 = pts[i + 2] || p2;
    context.bezierCurveTo(
      p1[0] + (p2[0] - p0[0]) / 6, p1[1] + (p2[1] - p0[1]) / 6,
      p2[0] - (p3[0] - p1[0]) / 6, p2[1] - (p3[1] - p1[1]) / 6,
      p2[0], p2[1]
    );
  }
}

/* One series the way the app draws it: a 12%-opacity area under download, a
   plain line for upload, no markers. */
function drawSeries(context, pts, color, fill, width, height) {
  if (fill) {
    smoothPath(context, pts);
    context.lineTo(pts[pts.length - 1][0], height);
    context.lineTo(pts[0][0], height);
    context.closePath();
    context.fillStyle = fill;
    context.fill();
  }
  smoothPath(context, pts);
  context.strokeStyle = color;
  context.lineWidth = 2;
  context.lineJoin = "round";
  context.lineCap = "round";
  context.stroke();
}

/* Canvas sized to its CSS box at device pixel ratio. Returns the CSS-pixel size. */
function fitCanvas(canvas, cssHeight) {
  const ratio = Math.min(window.devicePixelRatio || 1, 2);
  const width = canvas.clientWidth || canvas.parentElement.clientWidth;
  const height = cssHeight || canvas.clientHeight;
  canvas.width = Math.round(width * ratio);
  canvas.height = Math.round(height * ratio);
  canvas.style.height = height + "px";
  const context = canvas.getContext("2d");
  context.setTransform(ratio, 0, 0, ratio, 0, 0);
  return { context, width, height };
}

/* Draws now and again after a resize, which is the only thing that can
   invalidate a still frame. */
function onceAndOnResize(draw) {
  draw();
  addEventListener("resize", draw);
}

/* ---------------- page background: a still chart-recorder trace ---------------- */

(function background() {
  const canvas = $("trace");
  if (!canvas) return;
  const context = canvas.getContext("2d");

  onceAndOnResize(() => {
    const ratio = Math.min(window.devicePixelRatio || 1, 2);
    const width = window.innerWidth;
    const height = window.innerHeight;
    canvas.width = width * ratio;
    canvas.height = height * ratio;
    context.setTransform(ratio, 0, 0, ratio, 0, 0);
    context.clearRect(0, 0, width, height);

    for (let layer = 0; layer < 2; layer++) {
      const amplitude = height * (layer ? 0.052 : 0.078);
      const mid = height * (layer ? 0.72 : 0.34);
      const shift = layer ? 1.9 : 0;
      context.beginPath();
      for (let x = 0; x <= width; x += 6) {
        const p = x / width;
        const y = mid
          + Math.sin(p * 7.5 + shift) * amplitude
          + Math.sin(p * 17 + shift) * amplitude * 0.34;
        x === 0 ? context.moveTo(x, y) : context.lineTo(x, y);
      }
      const gradient = context.createLinearGradient(0, 0, width, 0);
      gradient.addColorStop(0, "rgba(10,132,255,0)");
      gradient.addColorStop(0.35, layer ? "rgba(94,92,230,0.30)" : "rgba(10,132,255,0.34)");
      gradient.addColorStop(1, "rgba(94,92,230,0)");
      context.strokeStyle = gradient;
      context.lineWidth = 1.4;
      context.stroke();
    }
  });
})();

/* ---------------- hero: one minute of traffic, held still ---------------- */

(function heroTrace() {
  const canvas = $("live");
  if (!canvas) return;

  const points = 84;
  const down = Array.from({ length: points }, (_, i) =>
    Math.max(0.1, 1.4 + Math.sin(i / 5.5) * 1.5 + Math.sin(i / 2.1) * 0.6));
  const up = down.map((v, i) => v * (0.16 + Math.abs(Math.sin(i / 7)) * 0.12));

  onceAndOnResize(() => {
    const { context, width, height } = fitCanvas(canvas, 150);
    const peak = Math.max(2, ...down) * 1.15;
    const x = (i) => (i / (points - 1)) * width;
    const y = (v) => height - (v / peak) * (height - 10) - 4;

    context.clearRect(0, 0, width, height);
    context.strokeStyle = GRID;
    context.lineWidth = 1;
    for (let g = 1; g <= 3; g++) {
      const gy = (height / 4) * g;
      context.beginPath();
      context.moveTo(0, gy);
      context.lineTo(width, gy);
      context.stroke();
    }

    const toPoints = (values) => values.map((v, i) => [x(i), y(v)]);
    drawSeries(context, toPoints(down), DOWN, "rgba(10,132,255,0.12)", width, height);
    drawSeries(context, toPoints(up), UP, null, width, height);

    // the reading head, where the menu-bar number comes from
    context.beginPath();
    context.arc(x(points - 1), y(down[points - 1]), 3, 0, Math.PI * 2);
    context.fillStyle = DOWN_HI;
    context.fill();
  });
})();

/* ---------------- live section: the floating window ---------------- */

(function floatingWindow() {
  const spark = $("hud-spark");
  if (!spark) return;
  const values = Array.from({ length: 40 }, (_, i) => 0.3 + Math.abs(Math.sin(i / 3.4)) * 0.9);
  const upValues = values.map((v, i) => v * (0.22 + Math.abs(Math.sin(i / 5)) * 0.14));

  onceAndOnResize(() => {
    const { context, width, height } = fitCanvas(spark, 44);
    context.clearRect(0, 0, width, height);
    const peak = Math.max(...values) * 1.1;
    const toPoints = (series) =>
      series.map((v, i) => [(i / (series.length - 1)) * width, height - (v / peak) * (height - 4) - 2]);
    drawSeries(context, toPoints(values), DOWN, "rgba(10,132,255,0.12)", width, height);
    drawSeries(context, toPoints(upValues), UP, null, width, height);
  });
})();

/* ---------------- per-app table ---------------- */

(function appTable() {
  const body = $("tbl-body");
  if (!body) return;

  const apps = [
    { name: "Google Chrome", tile: "linear-gradient(140deg,#4C8DF6,#2B6BD8)", in: 2.43, out: 0.2 },
    { name: "Slack", tile: "linear-gradient(140deg,#8E5BE8,#5E5CE6)", in: 0.84, out: 0.11 },
    { name: "Spotify", tile: "linear-gradient(140deg,#37C77E,#199E5C)", in: 0.61, out: 0.02 },
    { name: "Figma", tile: "linear-gradient(140deg,#E0559B,#B33F7E)", in: 0.35, out: 0.09 },
    { name: "nsurlsessiond", tile: "linear-gradient(140deg,#6E7891,#4A5266)", in: 0.22, out: 0.01 },
    { name: "WhatsApp", tile: "linear-gradient(140deg,#39C06A,#1D8F4B)", in: 0.09, out: 0.03 },
  ];

  const format = (gb) => (gb >= 1 ? gb.toFixed(2) + " GB" : Math.round(gb * 1024) + " MB");
  const total = (app) => app.in + app.out;
  const sorted = [...apps].sort((a, b) => total(b) - total(a));
  const max = total(sorted[0]);

  body.innerHTML = sorted.map((app, i) =>
    `<div class="trow${i === 0 ? " hot" : ""}">` +
    `<span class="t-app"><span class="t-tile" style="background:${app.tile}"></span>` +
    `<span class="t-name">${app.name}</span></span>` +
    `<span class="t-in mono">${format(app.in)}</span>` +
    `<span class="t-out mono">${format(app.out)}</span>` +
    `<span class="t-total">${format(total(app))}</span>` +
    `<i class="t-bar" style="width:${(total(app) / max) * 100}%"></i>` +
    `</div>`
  ).join("");
})();

/* ---------------- history chart ---------------- */

(function history() {
  const canvas = $("hist");
  if (!canvas) return;

  const make = (count, base, spread, seed) =>
    Array.from({ length: count }, (_, i) => {
      const wave = Math.sin((i + seed) / 2.3) + Math.sin((i + seed) / 5.1) * 0.7;
      return Math.max(0.15, base + wave * spread + ((i * 37) % 11) / 22);
    });

  const ranges = {
    7: { down: make(7, 2.1, 0.9, 1), label: "Seven days, split at your local midnight." },
    30: { down: make(30, 1.9, 0.8, 3), label: "Thirty days of daily totals." },
    90: { down: make(90, 1.8, 0.7, 5), label: "Ninety days of hourly totals, folded into days." },
    all: { down: make(150, 1.7, 0.75, 7), label: "Everything Sysline has recorded on this Mac." },
  };
  Object.values(ranges).forEach((range) => {
    range.up = range.down.map((v, i) => v * (0.28 + ((i * 13) % 7) / 40));
  });

  let current = "7";

  const draw = () => {
    const range = ranges[current];
    const { context, width, height } = fitCanvas(canvas, 190);
    const padBottom = 18;
    const plot = height - padBottom;
    const count = range.down.length;
    const peak = Math.max(...range.down) * 1.12;

    context.clearRect(0, 0, width, height);
    context.strokeStyle = GRID;
    context.lineWidth = 1;
    for (let g = 0; g <= 3; g++) {
      const gy = (plot / 3) * g;
      context.beginPath();
      context.moveTo(0, gy);
      context.lineTo(width, gy);
      context.stroke();
    }

    const toPoints = (series) =>
      series.map((v, i) => [(i / (count - 1)) * width, plot - (v / peak) * (plot - 8)]);
    drawSeries(context, toPoints(range.down), DOWN, "rgba(10,132,255,0.12)", width, plot);
    drawSeries(context, toPoints(range.up), UP, null, width, plot);

    context.fillStyle = DIM;
    context.font = "10px 'IBM Plex Mono', monospace";
    context.fillText(current === "all" ? "oldest" : count + " days ago", 0, height - 4);
    const rightLabel = "today";
    context.fillText(rightLabel, width - context.measureText(rightLabel).width, height - 4);

    const totalDown = range.down.reduce((sum, v) => sum + v, 0);
    const totalUp = range.up.reduce((sum, v) => sum + v, 0);
    $("hist-total").textContent =
      "↓ " + totalDown.toFixed(1) + " GB   ↑ " + totalUp.toFixed(1) + " GB";
  };

  // The one thing that changes, and only because the visitor clicked it.
  const setRange = (key) => {
    current = key;
    $("hist-cap").textContent = ranges[key].label;
    document.querySelectorAll(".rchip[data-r]").forEach((chip) => {
      chip.classList.toggle("on", chip.dataset.r === key);
    });
    draw();
  };

  document.querySelectorAll(".rchip[data-r]").forEach((chip) => {
    chip.addEventListener("click", () => setRange(chip.dataset.r));
  });
  addEventListener("resize", draw);
  setRange("7");
})();

/* ---------------- speed gauge: the dial the app draws ---------------- */

(function gauge() {
  const canvas = $("gauge");
  if (!canvas) return;

  const MARKS = [0, 1, 5, 10, 25, 50, 100, 250, 500, 1000];
  const START = 145;
  const SWEEP = 250;

  // A finished example test, so the dial reads like a result rather than a loop.
  const SAMPLE = { down: 61.4, up: 22.8, ping: 38, jitter: 6, peak: 78.2 };

  // Piecewise-log scale: each mark owns an equal slice of the arc, so a café
  // connection and a gigabit line both get room on one face.
  const fraction = (value) => {
    const segments = MARKS.length - 1;
    if (value <= 0) return 0;
    if (value >= MARKS[segments]) return 1;
    for (let i = 1; i < MARKS.length; i++) {
      if (value <= MARKS[i]) {
        const f0 = (i - 1) / segments;
        const t = (value - MARKS[i - 1]) / (MARKS[i] - MARKS[i - 1]);
        return f0 + t / segments;
      }
    }
    return 1;
  };

  let shown = SAMPLE.down;
  let peak = SAMPLE.peak;
  let color = DOWN;

  /* Activity scores, ported from SpeedRating in the app so the web and the Mac
     grade a connection identically. 0 = not measured yet. */
  const SCORES = {
    browsing: (down, up, ping) =>
      down < 1 ? 0 : ping <= 30 && down >= 5 ? 5 : ping <= 60 && down >= 3 ? 4 : ping <= 100 ? 3 : ping <= 200 ? 2 : 1,
    gaming: (down, up, ping) =>
      ping <= 0 ? 0 : ping <= 20 ? 5 : ping <= 45 ? 4 : ping <= 70 ? 3 : ping <= 120 ? 2 : 1,
    streaming: (down) =>
      down < 1 ? 0 : down >= 25 ? 5 : down >= 15 ? 4 : down >= 8 ? 3 : down >= 3 ? 2 : 1,
    calls: (down, up, ping) => {
      const band = Math.min(down, up);
      if (band < 0.5) return 0;
      let score = band >= 6 ? 5 : band >= 3 ? 4 : band >= 1.5 ? 3 : 2;
      if (ping > 200) score = Math.max(1, score - 2);
      else if (ping > 100) score = Math.max(1, score - 1);
      return score;
    },
  };

  const setRatings = (down, up, ping) => {
    Object.keys(SCORES).forEach((key) => {
      const element = $("r-" + key);
      if (!element) return;
      const score = SCORES[key](down, up, ping);
      element.innerHTML = Array.from({ length: 5 }, (_, i) =>
        `<b class="${i < score ? "on" : ""}"></b>`).join("");
      element.parentElement.classList.toggle("scored", score > 0);
    });
  };

  const draw = () => {
    // Measured off the wrapper, never the canvas: the canvas' own width is an
    // output of this function, so reading it back would feed into itself.
    const size = Math.min(canvas.parentElement.clientWidth || 360, 360);
    const ratio = Math.min(window.devicePixelRatio || 1, 2);
    const h = size * 0.86;
    canvas.width = size * ratio;
    canvas.height = h * ratio;
    canvas.style.width = size + "px";
    canvas.style.height = h + "px";
    const context = canvas.getContext("2d");
    context.setTransform(ratio, 0, 0, ratio, 0, 0);

    const w = size;
    // Centre and radius leave room for the label ring; at 0.38 the marks either
    // side of the top (25, 50) fall off the canvas.
    const cx = w / 2;
    const cy = size * 0.5;
    const radius = size * 0.36;
    const track = size * 0.042;
    const angle = (f) => ((START + f * SWEEP) * Math.PI) / 180;
    const point = (f, r) => [cx + r * Math.cos(angle(f)), cy + r * Math.sin(angle(f))];
    const arc = (from, to, r, width, stroke) => {
      context.beginPath();
      context.arc(cx, cy, r, angle(from), angle(to));
      context.lineWidth = width;
      context.lineCap = "round";
      context.strokeStyle = stroke;
      context.stroke();
    };

    context.clearRect(0, 0, w, h);
    arc(0, 1, radius, track, "rgba(150,160,220,0.11)");

    const segments = MARKS.length - 1;
    context.font = `500 ${size * 0.042}px 'IBM Plex Mono', monospace`;
    context.textAlign = "center";
    context.textBaseline = "middle";
    for (let i = 0; i <= segments * 3; i++) {
      const f = i / (segments * 3);
      const major = i % 3 === 0;
      const outer = radius + track * 0.9;
      const inner = outer - (major ? size * 0.032 : size * 0.016);
      const [x1, y1] = point(f, inner);
      const [x2, y2] = point(f, outer);
      context.beginPath();
      context.moveTo(x1, y1);
      context.lineTo(x2, y2);
      context.lineWidth = major ? 1.6 : 1;
      context.strokeStyle = major ? "rgba(200,208,240,0.42)" : "rgba(150,160,220,0.2)";
      context.stroke();
      if (major) {
        const [lx, ly] = point(f, radius + size * 0.075);
        context.fillStyle = DIM;
        context.fillText(String(MARKS[i / 3]), lx, ly);
      }
    }

    const f = fraction(shown);
    if (f > 0) {
      context.save();
      context.shadowColor = color;
      context.shadowBlur = size * 0.05;
      arc(0, f, radius, track, color);
      context.restore();
      arc(0, f, radius, track, color);
    }

    const peakF = fraction(peak);
    if (peakF > f + 0.005) {
      const [px1, py1] = point(peakF, radius - track * 0.8);
      const [px2, py2] = point(peakF, radius + track * 0.8);
      context.beginPath();
      context.moveTo(px1, py1);
      context.lineTo(px2, py2);
      context.lineWidth = 2;
      context.strokeStyle = "rgba(224,85,155,0.75)";
      context.stroke();
    }

    const [nx, ny] = point(f, radius - track * 1.6);
    context.beginPath();
    context.moveTo(cx, cy);
    context.lineTo(nx, ny);
    context.lineWidth = size * 0.014;
    context.lineCap = "round";
    context.strokeStyle = color;
    context.stroke();

    const hub = size * 0.05;
    context.beginPath();
    context.arc(cx, cy, hub / 2, 0, Math.PI * 2);
    context.fillStyle = color;
    context.fill();
    context.beginPath();
    context.arc(cx, cy, hub / 4, 0, Math.PI * 2);
    context.fillStyle = "#0D1020";
    context.fill();
  };

  onceAndOnResize(draw);
  setRatings(SAMPLE.down, SAMPLE.up, SAMPLE.ping);
})();

/* ---------------- latest version, read from the releases API ---------------- */

(async function version() {
  const meta = $("dl-meta");
  const getMeta = $("get-meta");
  if (!meta) return;
  try {
    const response = await fetch(
      "https://api.github.com/repos/azharbinanwar/Sysline/releases/latest",
      { headers: { Accept: "application/vnd.github+json" } }
    );
    if (!response.ok) return;               // rate-limited or offline: keep the static text
    const release = await response.json();
    if (!release.tag_name) return;
    const version = release.tag_name.replace(/^v/, "");
    const dmg = (release.assets || []).find((asset) => asset.name === "Sysline.dmg");
    const size = dmg ? ` · ${(dmg.size / 1e6).toFixed(1)} MB` : "";
    meta.textContent = `Version ${version} · Apple Silicon${size}`;
    if (getMeta) getMeta.textContent = `Version ${version}${size} · updates in place`;
  } catch {
    /* the static text already says everything except the number */
  }
})();

/* ---------------- copy buttons ---------------- */

document.querySelectorAll(".term").forEach((term) => {
  term.addEventListener("click", async () => {
    const text = term.querySelector("code").textContent;
    try {
      await navigator.clipboard.writeText(text);
    } catch {
      const field = document.createElement("textarea");
      field.value = text;
      document.body.appendChild(field);
      field.select();
      document.execCommand("copy");
      field.remove();
    }
    const label = term.querySelector(".t-copy");
    label.textContent = "Copied";
    term.classList.add("copied");
    setTimeout(() => {
      label.textContent = "Copy";
      term.classList.remove("copied");
    }, 1600);
  });
});
