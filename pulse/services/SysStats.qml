pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// the system out of /proc and sysfs every 2 s while the altar is open (detailed); perf — the Performance tab: processes and clocks on top;
// cat — the cat jogging in the bar tray (RunCat): it eats cpu, same cadence, but never detailed — only /proc/stat, meminfo and uptime.
// one sh probe per tick that cats everything it needs and labels it: parsing happens when the pipe is done, nothing
// blocks the ui thread (blocking reads every 2 s janked the altar while it sampled)
Singleton {
    id: root

    property bool detailed: false
    property bool perf: false
    property bool cat: false

    property real cpu: 0          // 0…1
    property var cores: []        // 0…1 per core
    property real cpuTemp: 0      // °C
    property real cpuFreq: 0      // ghz, average
    property string load: ""
    property real mem: 0          // 0…1
    property real memUsed: 0      // GiB
    property real memTotal: 0
    property real swapUsed: 0
    property real cache: 0
    property real gpu: 0          // 0…1
    property real gpuTemp: 0
    property real vramUsed: 0     // GiB
    property real vramTotal: 0
    property var disks: []        // [{ mount, used 0…1, size }]
    property string iface: ""
    property real rx: 0           // bytes/s
    property real tx: 0
    property var procs: []        // [[name, %cpu], …]
    property real uptime: 0       // s

    property var prev: ({})
    property var prevNet: [[0, 0], 0] // [[rx, tx], ms]

    // gpu and sensors aren't hardwired, like in caelestia: nvidia-smi present — take it from there; else the first drm card with
    // gpu_busy_percent (amdgpu), its vram and its hwmon. cpu temp — the first known sensor. nothing found — zeros
    property string gpuType: ""   // "nvidia" | "drm" | ""
    property string card: ""      // /sys/class/drm/cardN/device
    property string gpuDev: ""    // the card's pci device in sysfs: power/runtime_status — is it asleep
    property string gpuHwmon: ""
    property var hwmons: ({})     // hwmonN by sensor name
    function hwmon(names) { const n = names.find(n => root.hwmons[n]); return n ? root.hwmons[n] + "/temp1_input" : ""; }

    Process {
        running: true
        command: ["sh", "-c", `for h in /sys/class/hwmon/hwmon*; do echo "hwmon $(cat $h/name) $h"; done
command -v nvidia-smi >/dev/null && nvidia-smi -L >/dev/null 2>&1 && echo "nvidia $(ls -d /sys/bus/pci/drivers/nvidia/*:* 2>/dev/null | head -1)"
for c in /sys/class/drm/card*/device; do [ -e "$c/gpu_busy_percent" ] && { echo "card $c $(ls -d $c/hwmon/hwmon* 2>/dev/null | head -1)"; break; }; done`]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = {};
                for (const l of text.trim().split("\n")) {
                    const [k, a, b] = l.split(" ");
                    if (k === "hwmon") m[a] = b;
                    else if (k === "nvidia") { root.gpuType = "nvidia"; root.gpuDev = a ?? ""; }
                    else if (k === "card" && root.gpuType !== "nvidia") { root.gpuType = "drm"; root.card = root.gpuDev = a; root.gpuHwmon = b ?? ""; }
                }
                root.hwmons = m;
            }
        }
    }
    Process {
        id: nvidia
        command: ["nvidia-smi", "--query-gpu=utilization.gpu,temperature.gpu,memory.used,memory.total", "--format=csv,noheader,nounits"]
        stdout: StdioCollector {
            onStreamFinished: {
                // nvidia-smi on error prints words, not numbers — take what's finite, keep the rest as it was
                const [u, t, used, total] = text.trim().split("\n")[0].split(",").map(Number);
                if (Number.isFinite(u)) root.gpu = u / 100;
                if (Number.isFinite(t)) root.gpuTemp = t;
                if (Number.isFinite(used) && Number.isFinite(total) && total > 0) {
                    root.vramUsed = used / 1024;
                    root.vramTotal = total / 1024;
                }
            }
        }
    }

    Process {
        id: df
        command: ["df", "-B1", "--output=target,used,size", "/", "/home"]
        stdout: StdioCollector {
            onStreamFinished: {
                const seen = {};
                root.disks = text.trim().split("\n").slice(1).map(l => l.trim().split(/\s+/))
                    .filter(([m, u, s]) => !seen[u + s] && (seen[u + s] = true))
                    .map(([m, u, s]) => ({ mount: m === "/" ? "root" : m.slice(1), used: +s > 0 ? u / s : 0, size: +s || 0 }));
            }
        }
    }

    Process {
        id: ps
        command: ["ps", "-eo", "comm,%cpu", "--sort=-%cpu", "--no-headers"]
        stdout: StdioCollector {
            onStreamFinished: root.procs = text.trim().split("\n").map(l => {
                const m = l.trim().match(/^(.*?)\s+([\d.]+)$/);
                return m ? [m[1], +m[2]] : [l, 0];
            }).filter(p => p[0] !== "ps").slice(0, 4)
        }
    }

    // the probe: stat/meminfo/uptime always, the rest only when someone is looking
    Process {
        id: probe
        stdout: StdioCollector { onStreamFinished: root.parse(text) }
    }
    function sample() {
        if (probe.running) return; // a slow tick is dropped, not stacked
        const c = ["echo @stat; cat /proc/stat", "echo @meminfo; cat /proc/meminfo", "echo @uptime; cat /proc/uptime"];
        if (detailed) {
            c.push("echo @loadavg; cat /proc/loadavg",
                   `echo @cputemp; cat ${root.hwmon(["k10temp", "coretemp", "zenpower", "cpu_thermal"])} 2>/dev/null`,
                   `echo @gpupm; cat ${root.gpuDev}/power/runtime_status 2>/dev/null`);
            if (root.gpuType === "drm")
                c.push(`echo @gpu; cat ${root.card}/gpu_busy_percent 2>/dev/null`,
                       `cat ${root.card}/mem_info_vram_used 2>/dev/null`,
                       `cat ${root.card}/mem_info_vram_total 2>/dev/null`,
                       `cat ${root.gpuHwmon}/temp1_input 2>/dev/null`);
            c.push("echo @route; cat /proc/net/route", "echo @netdev; cat /proc/net/dev");
        }
        if (perf) c.push("echo @cpuinfo; cat /proc/cpuinfo");
        probe.command = ["sh", "-c", c.join("; ")];
        probe.running = true;
    }
    function sections(t) {
        const out = {};
        for (const chunk of t.split(/^@/m).slice(1)) {
            const i = chunk.indexOf("\n");
            out[chunk.slice(0, i)] = chunk.slice(i + 1);
        }
        return out;
    }
    function parse(t) {
        const s = sections(t);
        const line = k => (s[k] ?? "").split("\n");

        // cpu: the total line and the cores
        const next = {}, cores = [];
        for (const l of line("stat")) {
            if (!l.startsWith("cpu")) break;
            const p = l.trim().split(/\s+/), f = p.slice(1).map(Number);
            if (f.length < 5) continue;
            const idle = f[3] + f[4], total = f.reduce((a, b) => a + b, 0);
            const o = root.prev[p[0]] ?? [idle, total];
            const u = total > o[1] ? 1 - (idle - o[0]) / (total - o[1]) : 0;
            next[p[0]] = [idle, total];
            if (p[0] === "cpu") root.cpu = u; else cores.push(u);
        }
        root.prev = next;
        root.cores = cores;

        const kv = {};
        for (const l of line("meminfo")) {
            const m = l.match(/^(\w+):\s+(\d+)/);
            if (m) kv[m[1]] = +m[2] / 1048576;
        }
        root.memTotal = kv.MemTotal || 0;
        root.memUsed = Math.max(0, root.memTotal - (kv.MemAvailable || 0));
        root.mem = root.memTotal > 0 ? root.memUsed / root.memTotal : 0;
        root.swapUsed = Math.max(0, (kv.SwapTotal || 0) - (kv.SwapFree || 0));
        root.cache = kv.Cached || 0;

        root.uptime = parseFloat(s.uptime) || 0;
        if (!root.detailed) return;

        root.load = line("loadavg")[0]?.split(" ").slice(0, 3).join(" ") ?? "";
        root.cpuTemp = (parseFloat(s.cputemp) || 0) / 1000;
        // polling wakes the hybrid laptop's dgpu, and polled every 2 s it won't fall back asleep (nvidia-smi for sure).
        // asleep means idle: 0, and the card stays untouched
        if ((s.gpupm ?? "").startsWith("suspend")) { root.gpu = 0; root.gpuTemp = 0; }
        else if (root.gpuType === "nvidia") nvidia.running = true;
        else {
            const g = line("gpu").map(Number);
            root.gpu = (g[0] || 0) / 100;
            root.gpuTemp = (g[3] || 0) / 1000;
            root.vramUsed = (g[1] || 0) / 1073741824;
            root.vramTotal = (g[2] || 0) / 1073741824;
        }

        // network: the interface behind the default route
        const r = line("route").find(l => l.split("\t")[1] === "00000000");
        root.iface = r ? r.split("\t")[0] : "";
        const dev = line("netdev").find(l => l.trim().startsWith(root.iface + ":"));
        if (dev) {
            const f = dev.split(":")[1].trim().split(/\s+/).map(Number), now = Date.now();
            const [px, pt] = root.prevNet, dt = (now - pt) / 1000;
            if (pt && dt > 0) { root.rx = (f[0] - px[0]) / dt; root.tx = (f[8] - px[1]) / dt; }
            root.prevNet = [[f[0], f[8]], now];
        }

        if (root.perf) top(s.cpuinfo ?? "");
    }

    // disks move slowly — once per opening
    onDetailedChanged: if (detailed) df.running = true
    // startup: the first cpu sample, so the first open doesn't diff against zero
    Component.onCompleted: sample()

    Timer {
        interval: 2000
        running: root.detailed || root.cat
        repeat: true
        triggeredOnStart: true
        onTriggered: root.sample()
    }

    // clocks and processes — Performance only; opened the tab — run at once, don't wait for the tick
    onPerfChanged: if (perf) sample()
    function top(cpuinfo) {
        const mhz = cpuinfo.match(/cpu MHz\s*:\s*[\d.]+/g) ?? [];
        root.cpuFreq = mhz.reduce((a, l) => a + parseFloat(l.split(":")[1]), 0) / Math.max(1, mhz.length) / 1000;
        ps.running = true;
    }

    function rate(b) {
        return b > 1048576 ? (b / 1048576).toFixed(1) + " mb/s" : Math.round(b / 1024) + " kb/s";
    }
}
