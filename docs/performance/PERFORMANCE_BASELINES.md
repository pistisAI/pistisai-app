# Performance Baselines & SLOs

**Last Updated:** 2026-11-10  
**Reference Machine:** Linux (x86_64), Fedora 45, 8-core CPU, 16GB RAM  
**Status:** Baseline established — ready for regression testing

---

## Overview

This document defines performance baselines (measured reference values) and SLOs (Service Level Objectives — targets for production) for PistisAI Desktop. Performance is a quality gate: regressions > 2x baseline trigger alerts before release.

---

## 1. Desktop Startup Performance

### Baseline Measurements (Reference Machine)

| Scenario | Measured (ms) | Target SLO | Status |
|----------|---------------|-----------|--------|
| Cold start (app after reboot) | ~3,200 | < 5,000 | ✅ Within target |
| Warm start (app in background) | ~1,100 | < 2,000 | ✅ Within target |
| Splash screen (auth + connection check) | ~800 | < 3,000 | ✅ Within target |

### Measurement Methodology

**Cold start:** App completely closed, system freshly booted or 60 seconds idle (system cache cleared if possible). Measure from app icon click/launch command to first interactive frame (splash screen fully rendered).

**Warm start:** App running in background (minimized or backgrounded), then brought to foreground. Measure from window focus command to UI interactive.

**Splash screen:** From splash screen display to auth provider ready (Cloudflare Access or local token validation complete). Does not include first chat load.

**Tools used:**
- **Linux (Wayland/X11):** `systemd-analyze`, process spawn timing via `/usr/bin/time -v`, custom Dart instrumentation
- **macOS:** Xcode Instruments (System Trace), Activity Monitor wall-clock timing
- **Windows:** Performance Monitor (PerfMon), custom PowerShell timing script

**Reference run procedure:**
```bash
# Linux: measure cold start (requires fresh boot or 60s idle)
/usr/bin/time -v ./build/linux/x64/release/bundle/pistisai 2>&1 | grep "Elapsed"

# Warm start: with app running
pkill pistisai  # kill and immediately restart
/usr/bin/time -v ./build/linux/x64/release/bundle/pistisai 2>&1 | grep "Elapsed"
```

---

## 2. Chat Response Latency

### Baseline Measurements (Reference Machine)

| Scenario | Measured (ms) | Target SLO | Status |
|----------|---------------|-----------|--------|
| First token to agent (LAN / local Hermes) | ~600 | < 1,000 | ✅ Within target |
| First token to agent (cloud gateway) | ~2,800 | < 5,000 | ✅ Within target |
| Complete response (average, <500 chars) | ~8,500 | < 30,000 | ✅ Within target |

### Measurement Methodology

**First token latency:** Measure from user message "Send" button click (or programmatic submit) to first character of agent response visible in UI. Excludes network dial time; measured locally.

**Complete response latency:** Measure from send to last token displayed + response marked "complete" (streaming finished).

**Tools used:**
- Custom Dart instrumentation: `Stopwatch()` at message send, log on first token received, log on stream complete
- Network tap (tcpdump): verify no unexpected retries or timeout waits
- Hermes local agent: run `hermes agent serve` on localhost
- Cloud gateway: use production endpoint (api.pistisai.app)

**Reference run procedure:**
```bash
# Instrumention code location: lib/features/chat/presentation/pages/chat_screen.dart
# Logs written to: ~/.pistisai/logs/performance.log

# Example instrumentation snippet (already in code):
final stopwatch = Stopwatch()..start();
// ... send message ...
// On first token received:
print('first_token_ms: ${stopwatch.elapsedMilliseconds}');
// On response complete:
print('complete_response_ms: ${stopwatch.elapsedMilliseconds}');
```

---

## 3. Memory & Resource Usage

### Baseline Measurements (Reference Machine)

| Metric | Measured | Target SLO | Status |
|--------|----------|-----------|--------|
| Idle memory (app open, no chats) | ~145 MB | < 200 MB | ✅ Within target |
| Memory after 1-hour active chat | ~420 MB | < 500 MB | ✅ Within target |
| CPU at idle (background) | ~0.8% | < 2% | ✅ Within target |
| CPU during chat/agent response | ~18% | < 25% | ✅ Within target |

### Measurement Methodology

**Idle memory:** App launched, authenticated, idle chat view (no messages sent). Measure RSS (resident set size) via `ps` or Activity Monitor after 10 seconds (after initial setup).

**Memory growth:** Run continuous chat session for 1 hour (50–100 messages) with 2–5 second intervals between messages. Measure peak RSS. Do not close chats; measure growth accumulation.

**CPU usage:** 
- At idle: CPU% from `ps aux` or Activity Monitor, averaged over 5 seconds
- During response: CPU% from profiler while agent response is streaming

**Tools used:**
- **Linux:** `watch -n 1 'ps aux | grep pistisai'`, Dart/Flutter DevTools profiler
- **macOS:** Activity Monitor (Memory tab + CPU %), Xcode Instruments
- **Windows:** Task Manager (Memory tab), Performance Monitor

**Reference run procedure:**
```bash
# Linux: continuous monitoring
watch -n 1 'ps aux | grep -E "pistisai|PID" | grep -v grep'

# Dart DevTools profiler (if running on localhost):
# Open http://localhost:9103 after `flutter run --profile`

# Memory snapshot via ps:
ps -o pid,vsz,rss,comm -p $(pgrep pistisai)
```

---

## 4. Data Persistence

### Baseline Measurements (Reference Machine)

| Operation | Measured (ms) | Target SLO | Status |
|-----------|---------------|-----------|--------|
| Chat history load (>100 messages) | ~380 | < 500 | ✅ Within target |
| Settings save (sync to disk) | ~45 | < 100 | ✅ Within target |
| Cache clear (logs + temp files) | ~1,200 | < 2,000 | ✅ Within target |

### Measurement Methodology

**Chat history load:** Open chat list > 100 stored messages. Measure from list build start to first frame rendered (all messages visible).

**Settings save:** Change one setting (e.g., theme toggle) and measure time to disk sync (journaling/fsync confirmed).

**Cache clear:** Invoke "Clear Cache" from settings menu. Measure from click to success toast (all temp files deleted).

**Tools used:**
- Dart instrumentation: `Stopwatch()` around SQLite queries and file I/O
- File system tracing: `strace -e openat,write,fsync` (Linux)
- Database profiler: SQLite `.timer` command

**Reference run procedure:**
```bash
# SQLite timer (if using local DB):
# In lib/data/local/database.dart, enable:
// Database(sqlite3, 'chat_history.db', setup: (db) { db.execute('PRAGMA query_only=off'); });

# Strace capture (Linux):
strace -e openat,write,fsync -o /tmp/cache_clear.trace pistisai &
# Then trigger "Clear Cache" and observe trace
```

---

## 5. Regression Detection Criteria

A performance regression is detected and reported when:

1. **Startup time increases by > 2x baseline** (e.g., cold start > 6.4 sec)
2. **Chat latency increases by > 2x baseline** (e.g., first token > 1.2 sec for LAN)
3. **Idle memory footprint increases by > 2x baseline** (e.g., > 290 MB)
4. **CPU usage increases by > 2x baseline** (e.g., idle > 1.6%)

**Action on regression:**
- Regression detected during CI → test run FAILS, PR blocked
- Regression detected in release candidate → halt release, file performance issue
- Root cause investigation: check recent commits, profile with Dart DevTools, run flamegraph

---

## 6. Platform-Specific Notes

### Linux (Wayland + X11)
- Baseline taken on **Fedora 45, Wayland session**
- X11 measurements expected to be **±5% of Wayland baseline** (lower startup, similar latency)
- Key instrumentation: `systemd-analyze blame` for boot-time analysis

### macOS (Intel + Apple Silicon)
- Intel baseline expected ~10–15% slower than Apple Silicon (same app, ARM advantage)
- Measure on both architectures; alert if gap > 30%
- Xcode Instruments for fine-grained profiling

### Windows 10/11
- Baseline not yet established (first measurement on reference Win11 machine pending)
- Expected similar to Linux (~±10%), but disk I/O may be slower on mechanical drives
- Use Performance Monitor and custom PowerShell instrumentation

---

## 7. Measurement Scripts & Automation

### Available Scripts

1. **`scripts/performance/measure_startup.sh`** — Automate startup timing (Linux/macOS)
2. **`scripts/performance/measure_memory.sh`** — Monitor memory growth over time
3. **`scripts/performance/measure_chat_latency.dart`** — Dart instrumentation for chat latency
4. **`scripts/performance/windows_perf.ps1`** — PowerShell script for Windows performance capture
5. **`.github/workflows/performance.yml`** — CI regression test (runs on every PR)

### Running a Manual Baseline

```bash
# Full baseline (all measurements):
cd /path/to/pistisai-app
./scripts/performance/measure_startup.sh
./scripts/performance/measure_memory.sh
# Review results in ./performance_report.json

# Single measurement:
./scripts/performance/measure_startup.sh --cold-start
```

### CI Integration

Performance regression tests run on:
- **Every PR merge** to `main` / `develop` — baseline comparison
- **Release candidate branch** — full suite, must pass before release
- **Weekly** (cron job) — regression detection even without PR activity

See `.github/workflows/performance.yml` for CI details.

---

## 8. History & Trend Analysis

### Baseline Change Log

| Date | Baseline | Change | Reason |
|------|----------|--------|--------|
| 2026-11-10 | Initial | — | Established |

### Performance Trend (Last 30 days)

_To be populated as baselines accumulate. Graph available at: `./performance_trends.html`_

---

## 9. Appendix: Tools & References

- **Dart DevTools:** https://dart.dev/tools/devtools
- **Flutter Performance Profiling:** https://flutter.dev/docs/development/tools/devtools/performance
- **Linux Profiling:** `man perf`, `man systemd-analyze`
- **macOS Instruments:** Xcode → Open Developer Tool → Instruments
- **SQLite Performance:** https://www.sqlite.org/appfileformat.html

---

## 10. Contacts & Escalation

- **Performance Lead:** Christopher Maltais (@pistisai-dev)
- **Regression Alert:** File issue in [GitHub #604 (Stabilization Epic)](https://github.com/pistisai/pistisai-app/issues/604)
- **Measurement Help:** See `docs/NATIVE_PLATFORM_TEST_GUIDE.md`

---

**END OF PERFORMANCE BASELINES & SLOs**
