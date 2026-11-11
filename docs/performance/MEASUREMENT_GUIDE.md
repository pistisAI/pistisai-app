# Performance Measurement Guide

**Audience:** Developers, QA, Release Managers  
**Purpose:** How to run performance tests locally and interpret results  
**Status:** v1.0 (2026-11-10)

---

## Quick Start

### Linux/macOS
```bash
cd /path/to/pistisai-app

# Build the app in release mode first
flutter build linux   # or: flutter build macos

# Run startup performance test
./scripts/performance/measure_startup.sh

# Monitor memory during active chat (60 seconds)
./scripts/performance/measure_memory.sh

# View results
cat performance_report.json
```

### Windows
```powershell
cd C:\path\to\pistisai-app
flutter build windows

# Run startup test
.\scripts\performance\windows_perf.ps1 -Measurement "cold-start"

# Monitor memory for 5 minutes
.\scripts\performance\windows_perf.ps1 -Measurement "memory" -Duration 300
```

---

## Detailed Workflow

### 1. **Startup Performance Testing**

#### Cold Start (app after reboot)

**What it measures:** Time from clicking the app icon to seeing the main UI (splash screen rendered and auth complete).

**Steps:**
1. **Ensure app is not running:**
   ```bash
   pkill -f pistisai || true
   ```

2. **Clear system cache (optional, Linux only):**
   ```bash
   sudo sync; sudo sysctl -w vm.drop_caches=3
   ```

3. **Reboot or wait 60 seconds** to let caches clear naturally

4. **Run the measurement:**
   ```bash
   ./scripts/performance/measure_startup.sh --cold-start
   ```

5. **Interpret results:**
   - `< 3,200 ms` = ✅ **Within baseline**
   - `3,200 – 6,400 ms` = ⚠️ **Slight increase** (investigate)
   - `> 6,400 ms` = ❌ **Regression alert** (block release)

#### Warm Start (app in background → foreground)

**What it measures:** Time from switching app to foreground to seeing the main UI.

**Steps:**
1. **Start the app normally** (let it fully load)
2. **Minimize or background it** for 10 seconds
3. **Bring it back to foreground:**
   ```bash
   ./scripts/performance/measure_startup.sh --warm-start
   ```

4. **Interpret results:**
   - `< 1,100 ms` = ✅ **Within baseline**
   - `1,100 – 2,200 ms` = ⚠️ **Slight increase** (investigate)
   - `> 2,200 ms` = ❌ **Regression alert**

#### Splash Screen Time

**What it measures:** Time from splash screen display to auth provider ready (Cloudflare Access or token validation).

**Steps:**
1. **Enable performance logging** (see Instrumentation section below)
2. **Launch the app normally:**
   ```bash
   ./build/linux/x64/release/bundle/pistisai
   ```
3. **Check logs:**
   ```bash
   grep "splash_screen_ms" ~/.pistisai/logs/performance.log
   ```

4. **Interpret results:**
   - `< 800 ms` = ✅ **Within baseline**
   - `800 – 1,600 ms` = ⚠️ **Slight increase**
   - `> 1,600 ms` = ❌ **Regression alert**

---

### 2. **Memory & CPU Testing**

#### Idle Memory Footprint

**What it measures:** RAM used by the app when open but idle (no chats).

**Steps:**
1. **Launch the app:**
   ```bash
   ./build/linux/x64/release/bundle/pistisai &
   ```

2. **Wait for authentication to complete** (watch the splash screen finish)

3. **Check memory immediately (after 10 seconds):**
   ```bash
   ps -o pid,rss,comm -p $(pgrep pistisai) | awk '{print ($2/1024) " MB"}'
   ```

4. **Interpret results:**
   - `< 200 MB` = ✅ **Within baseline**
   - `200 – 400 MB` = ⚠️ **Slight increase**
   - `> 400 MB` = ❌ **Regression alert**

#### Memory Growth During Active Chat

**What it measures:** RAM growth over 1 hour of continuous chat activity.

**Steps:**
1. **Start the app and launch monitoring:**
   ```bash
   ./build/linux/x64/release/bundle/pistisai &
   sleep 3
   ./scripts/performance/measure_memory.sh --duration 3600  # 1 hour
   ```

2. **Interact with the app during measurement:**
   - Send 50–100 messages to an agent
   - Allow full responses to stream and complete
   - Wait 2–5 seconds between messages

3. **Review results:**
   ```bash
   cat memory_monitor.csv
   ```
   Last line shows the peak memory at the end of the test.

4. **Interpret results:**
   - `< 500 MB peak` = ✅ **Within baseline**
   - `500 – 1,000 MB peak` = ⚠️ **Potential leak** (investigate)
   - `> 1,000 MB peak` = ❌ **Likely memory leak**

#### CPU Usage

**Linux — Real-time CPU monitor:**
```bash
watch -n 1 'ps aux | grep pistisai | grep -v grep | awk "{print \$3 \" % CPU\"}"'
```

**macOS — Activity Monitor:**
- Open Activity Monitor
- Search for "pistisai"
- Watch "% CPU" column while chatting
- Should stay below 25% during response streaming

**Windows — Task Manager:**
- Press Ctrl+Shift+Esc
- Find pistisai process
- Watch CPU % column
- Should stay below 25%

**Interpret results:**
- Idle `< 2%` ✅, Active `< 25%` ✅
- Idle `2–4%` ⚠️, Active `25–50%` ⚠️
- Idle `> 4%` ❌, Active `> 50%` ❌

---

### 3. **Data Persistence Testing**

#### Chat History Load Time

**What it measures:** Time to render chat list with 100+ messages.

**Steps:**
1. **Pre-populate chats** (create 100+ message chats manually or via DB script)
2. **Restart the app**
3. **Open chat list:**
   - Measure from tap/click to all messages visible
   - Use Dart DevTools profiler for precision

4. **Interpret results:**
   - `< 500 ms` ✅
   - `500 – 1,000 ms` ⚠️
   - `> 1,000 ms` ❌

#### Settings Save Time

**What it measures:** Time for a settings change to hit disk.

**Steps:**
1. **Enable file-level tracing (optional):**
   ```bash
   strace -e openat,write,fsync -f ./build/linux/x64/release/bundle/pistisai
   ```

2. **Toggle a setting** (e.g., Theme)
3. **Measure time from click to "Saved" toast**
4. **Check system call log:**
   ```bash
   grep "fsync" /tmp/trace.log | tail -1
   ```

**Interpret results:**
- `< 100 ms` ✅
- `100 – 200 ms` ⚠️
- `> 200 ms` ❌

---

## Instrumentation

### Dart Performance Logging

Add to `lib/features/chat/presentation/pages/chat_screen.dart`:

```dart
void _sendMessage() {
  final stopwatch = Stopwatch()..start();
  
  // Send message...
  apiClient.sendMessage(message).then((_) {
    // On first token received:
    print('first_token_ms: ${stopwatch.elapsedMilliseconds}');
    
    // On complete response:
    print('complete_response_ms: ${stopwatch.elapsedMilliseconds}');
  });
}
```

**Log location:** `~/.pistisai/logs/performance.log`

### Extracting Data from Logs

```bash
# First token latency
grep "first_token_ms:" ~/.pistisai/logs/performance.log | tail -10

# Complete response time
grep "complete_response_ms:" ~/.pistisai/logs/performance.log | tail -10

# Memory snapshots
grep "memory_usage_mb:" ~/.pistisai/logs/performance.log
```

---

## Regression Investigation

If a test fails with a regression:

### 1. **Verify the result is reproducible**
```bash
# Run 3 times
for i in {1..3}; do ./scripts/performance/measure_startup.sh --cold-start; done
```

### 2. **Check recent commits**
```bash
git log --oneline -20
```

### 3. **Profile with Dart DevTools**
```bash
flutter run --profile
# Open http://localhost:9103 in browser
# Capture timeline during startup
```

### 4. **Compare builds**
```bash
# Profile mode (optimized but with debugging)
flutter build linux --profile

# Measure again
./scripts/performance/measure_startup.sh --cold-start
```

### 5. **Check dependency sizes**
```bash
cd app
flutter pub deps --style=list | wc -l  # Count packages

# Check for new large dependencies
git diff pubspec.lock | grep "^+" | head -20
```

### 6. **Report the issue**
Create a GitHub issue with:
- Measured time and baseline
- Platform & build mode
- Recent commits that might be involved
- Flamegraph / profiler output (if available)

---

## CI Integration

### GitHub Actions

Performance tests run automatically on:
- Every PR to `main` or `develop`
- Every merge to `main`
- Every release branch push
- Weekly schedule (Tuesday 9 AM UTC)

**View results:**
- GitHub Actions tab → Performance Regression Tests
- Scroll to "summary" job
- Click artifact links to download reports

### Local CI Simulation

Run the same checks locally before pushing:
```bash
# Build release
flutter build linux

# Run all performance tests
./scripts/performance/measure_startup.sh
./scripts/performance/measure_memory.sh --duration 300

# Check regression criteria
jq '.status' performance_report.json
```

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Script says "App binary not found" | Run `flutter build linux` (or macOS/windows) first |
| Permission denied on shell scripts | Run `chmod +x scripts/performance/*.sh` |
| PistisAI process won't die | `pkill -9 pistisai` (forceful) |
| Virtual display error (Linux) | Install `xvfb`: `sudo apt-get install xvfb` |
| Memory monitor shows 0 MB | Ensure app is running before starting monitor |
| CSV file empty after monitoring | Check app is still running: `pgrep pistisai` |
| Windows script won't run | Run PowerShell as Administrator; Set execution policy: `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser` |

---

## Reference Machine Specs

**Baseline measurements were taken on:**
- **OS:** Fedora 45 Linux (x86_64)
- **Desktop:** Wayland (GNOME 45)
- **CPU:** 8-core Intel (or equivalent)
- **RAM:** 16 GB
- **Disk:** SSD (NVMe)
- **Build mode:** Release (`flutter build linux --release`)

When testing on different hardware:
- Adjust thresholds proportionally to CPU/RAM specs
- Log the environment in each test report
- Compare only same-platform results (Linux ≠ Windows)

---

## Questions & Escalation

- **How do I interpret a memory CSV?** Each row is a timestamp with RSS (MB) and CPU%. Plot in a spreadsheet.
- **What's the difference between "profile" and "release" builds?** Release is faster but harder to debug. Profiling build is slower but gives profiler data.
- **Can I run these tests on CI?** Yes, see `.github/workflows/performance.yml` and the CI Integration section above.
- **File an issue:** [GitHub #604 — Desktop Stabilization](https://github.com/pistisai/pistisai-app/issues/604)

---

**END OF PERFORMANCE MEASUREMENT GUIDE**
