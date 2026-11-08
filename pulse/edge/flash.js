// the glyph composer's shapes: one flash cycle, 0…1 → how the edge strip looks, { o: opacity, f: fill }.
// edge.qml drives the real strip with this, prefs → edge lights previews the pattern under the cursor
// with the same math — what you see under the cursor is what you get
.pragma library

function ss(x) { x = Math.max(0, Math.min(1, x)); return x * x * (3 - 2 * x); }

function shape(pattern, p) {
    if (pattern === "wave") // the fill sweeps in, holds, drains
        return { o: 0.9, f: p < 0.45 ? ss(p / 0.45) : p < 0.6 ? 1 : 1 - ss((p - 0.6) / 0.4) };
    let o;
    if (pattern === "pulse") // a quick hit, then a long fall
        o = 0.15 + 0.85 * (p < 0.05 ? ss(p / 0.05) : 1 - ss((p - 0.05) / 0.85));
    else if (pattern === "double") // two knocks, then quiet
        o = (p < 0.05 || (p >= 0.12 && p < 0.17)) ? 1 : 0.15;
    else if (pattern === "blink") // hard on-off, no easing
        o = (p % 0.5) < 0.25 ? 1 : 0.15;
    else // breathe — in slow, out slower; the original
        o = 0.15 + 0.85 * (p < 0.3 ? ss(p / 0.3) : 1 - ss((p - 0.3) / 0.7));
    return { o: o, f: 1 };
}

// [name, what it does] — the picker in prefs reads this
var NAMES = [
    ["breathe", "in slow, out slower"],
    ["pulse", "a hit, then a long fall"],
    ["double", "two knocks, then quiet"],
    ["blink", "hard on-off"],
    ["wave", "the fill sweeps through"]
];
