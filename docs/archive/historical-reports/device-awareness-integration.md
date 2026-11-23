# Device Awareness + Mobile Connectivity + Tailscale Integration (#440)

## Overview

This implementation provides comprehensive device awareness, mobile network state tracking, and Tailscale VPN integration for PistisAI, enabling seamless mobile-to-PC connectivity and adaptive response strategies based on device context.

## Components

### 1. DeviceAwarenessService (`lib/services/device_awareness_service.dart`)

**Purpose:** Detects and tracks device type, network state, and contextual information.

**Features:**
- **Device Type Detection:** Distinguishes between desktop, laptop, mobile, tablet, and unknown device types
- **Network State Tracking:** Monitors WiFi, cellular, other, and offline connectivity states
- **OS Information:** Captures operating system type and version
- **Device Capabilities:** Detects GPS and cellular capabilities
- **Time-of-Day Classification:** Categorizes time into morning, afternoon, evening, and night
- **Context Caching:** Caches device context for 5 minutes to minimize polling
- **Real-time Updates:** Subscribes to connectivity changes

**Key APIs:**
```dart
// Get comprehensive device context
DeviceContext context = await DeviceAwarenessService.instance.getDeviceContext();

// Check network state
NetworkState state = await DeviceAwarenessService.instance.getNetworkState();

// Check specific connectivity
bool isWifi = await DeviceAwarenessService.instance.isWifiConnected();
bool isCellular = await DeviceAwarenessService.instance.isCellularConnected();

// Adaptive response decisions
if (context.shouldUseShortenedResponses()) {
  // Send brief responses for mobile/cellular devices
}
```

**DeviceContext JSON Schema:**
```json
{
  "device_type": "mobile|tablet|desktop|laptop|unknown",
  "device_is_tablet": true,
  "os_type": "Android|iOS|Windows|Linux|macOS",
  "os_version": "14.0",
  "network_state": "wifi|cellular|other|offline",
  "has_gps": true,
  "has_cellular": true,
  "timezone": "+05:00",
  "time_of_day": "morning|afternoon|evening|night",
  "timestamp": "2026-11-10T21:28:00.000Z"
}
```

### 2. TailscaleIntegrationService (`lib/services/tailscale_integration_service.dart`)

**Purpose:** Integrates with Tailscale VPN for secure device-to-device networking.

**Features:**
- **Daemon Status Monitoring:** Checks if Tailscale daemon is running
- **Device Discovery:** Lists all connected peers on the Tailscale network
- **Desktop Detection:** Automatically finds the primary desktop PC
- **Hermes API Access:** Constructs URLs for accessing Hermes via Tailscale
- **Connectivity Testing:** Verifies Hermes is reachable via Tailscale

**Key APIs:**
```dart
// Check if Tailscale is running
bool isRunning = await TailscaleIntegrationService.instance.isTailscaleDaemonRunning();

// Get Tailscale status
TailscaleStatus? status = await TailscaleIntegrationService.instance.getTailscaleStatus();

// Discover peers
List<TailscalePeer> peers = await TailscaleIntegrationService.instance.getTailscalePeers();

// Find desktop
TailscalePeer? desktop = await TailscaleIntegrationService.instance.findDesktopPeer();

// Get Hermes URL via Tailscale
String? url = await TailscaleIntegrationService.instance.getHermesApiUrlViaTs(
  hermesPort: '3000'
);

// Test connectivity
bool connected = await TailscaleIntegrationService.instance.testHermesConnectivityViaTailscale();
```

**TailscaleStatus JSON Schema:**
```json
{
  "is_running": true,
  "status": {
    "hostname": "my-desktop",
    "tailnet_name": "user.ts.net",
    "tailscale_ips": ["198.51.100.1"],
    "is_online": true,
    "dns": "8.8.8.8",
    "os": "linux"
  }
}
```

**TailscalePeer JSON Schema:**
```json
{
  "id": "peer-node-id",
  "hostname": "desktop-pc",
  "primary_ip": "198.51.100.2",
  "addresses": ["198.51.100.2"],
  "is_online": true,
  "os": "linux",
  "last_seen": "2026-11-10T21:28:00.000Z"
}
```

### 3. Router Server Integration (`lib/services/router_server.dart`)

**New Endpoints:**

#### GET `/api/device/context`
Returns comprehensive device context for the calling device.

**Response:**
```json
{
  "device_type": "mobile",
  "device_is_tablet": false,
  "os_type": "Android",
  "os_version": "14.0",
  "network_state": "wifi",
  "has_gps": true,
  "has_cellular": true,
  "timezone": "+05:00",
  "time_of_day": "afternoon",
  "timestamp": "2026-11-10T21:28:00.000Z"
}
```

#### GET `/api/device/network`
Returns current network state and connectivity details.

**Response:**
```json
{
  "network_state": "wifi",
  "is_connected": true,
  "is_wifi": true,
  "is_cellular": false
}
```

#### GET `/api/device/tailscale/status`
Returns Tailscale daemon status.

**Response:**
```json
{
  "is_running": true,
  "status": {
    "hostname": "my-device",
    "tailnet_name": "user.ts.net",
    "tailscale_ips": ["198.51.100.1"],
    "is_online": true,
    "os": "linux"
  }
}
```

#### GET `/api/device/tailscale/peers`
Returns list of connected Tailscale peers.

**Response:**
```json
{
  "peers": [
    {
      "id": "node-id",
      "hostname": "desktop-pc",
      "primary_ip": "198.51.100.2",
      "addresses": ["198.51.100.2"],
      "is_online": true,
      "os": "linux",
      "last_seen": "2026-11-10T21:28:00.000Z"
    }
  ],
  "count": 1
}
```

## Dependencies

Added to `pubspec.yaml`:
```yaml
connectivity_plus: ^6.1.0
device_info_plus: ^13.3.0  # Already present
```

## Testing

### Test Coverage

Three test suites verify full functionality:

1. **`test/services/device_awareness_service_test.dart`** (16 tests)
   - Singleton pattern ✓
   - Device context creation and serialization ✓
   - Network state tracking ✓
   - Connectivity checks ✓
   - Response adaptation logic ✓
   - Enum values ✓
   - Context caching ✓

2. **`test/services/tailscale_integration_service_test.dart`** (15 tests)
   - Singleton pattern ✓
   - Daemon status checking ✓
   - Status parsing and serialization ✓
   - Peer discovery ✓
   - Desktop detection ✓
   - Hermes API URL construction ✓
   - Connectivity testing ✓

3. **`test/services/device_awareness_integration_test.dart`** (11 tests)
   - End-to-end device context flow ✓
   - Network state transitions ✓
   - Adaptive response decisions ✓
   - Tailscale integration ✓
   - JSON schema validation ✓

**Run tests:**
```bash
cd pistisai-app

# Device awareness tests
flutter test test/services/device_awareness_service_test.dart -v

# Tailscale integration tests
flutter test test/services/tailscale_integration_service_test.dart -v

# Integration tests
flutter test test/services/device_awareness_integration_test.dart -v

# All device tests
flutter test test/services/device*.dart -v
```

## Usage Examples

### Mobile App Usage

```dart
void setupDeviceAwareness() {
  final awareness = DeviceAwarenessService.instance;
  
  // Initialize
  await awareness.initialize();
  
  // Get device context
  final context = await awareness.getDeviceContext();
  
  if (context.deviceType == DeviceType.mobile) {
    print('Running on mobile');
  }
  
  if (context.networkState == NetworkState.cellular) {
    print('Using cellular data');
  }
}

void setupTailscale() {
  final tailscale = TailscaleIntegrationService.instance;
  
  // Check if Tailscale is available
  if (await tailscale.isTailscaleDaemonRunning()) {
    // Get Hermes URL via Tailscale
    final url = await tailscale.getHermesApiUrlViaTs();
    print('Hermes via Tailscale: $url');
  }
}
```

### Desktop/Backend Usage

```dart
// In router server initialization
final routerServer = RouterServer(
  port: 1337,
  rateLimitManager: rateLimitManager,
  providers: providers,
  // ... other params
);

await routerServer.start();

// Endpoints now available:
// GET /api/device/context
// GET /api/device/network
// GET /api/device/tailscale/status
// GET /api/device/tailscale/peers
```

### Adaptive Response Logic

```dart
Future<String> generateResponse(String prompt, BuildContext context) async {
  final awareness = DeviceAwarenessService.instance;
  final deviceContext = await awareness.getDeviceContext();
  
  String response;
  
  if (deviceContext.shouldUseShortenedResponses()) {
    // Use concise responses for mobile/cellular
    response = await llm.completeShort(prompt);
  } else if (deviceContext.isOnTheGo()) {
    // Medium response for mobile but on WiFi
    response = await llm.completeMedium(prompt);
  } else {
    // Full response for desktop
    response = await llm.completeFull(prompt);
  }
  
  return response;
}
```

## Architecture Decisions

### 1. Singleton Pattern
Both services use singleton instances to maintain state across the app lifetime and ensure consistent context.

### 2. Event-Based Network Tracking
Rather than polling, `DeviceAwarenessService` subscribes to `connectivity_plus` stream for real-time network state changes.

### 3. Context Caching (5-minute TTL)
Device context is expensive to gather (requires multiple platform calls). Caching reduces overhead while staying fresh.

### 4. JSON Schema for Serialization
Both services provide `toJson()` and `fromJson()` for reliable cross-process communication via HTTP/REST APIs.

### 5. Tailscale Local API Integration
Rather than requiring special permissions or setup, `TailscaleIntegrationService` queries the local Tailscale daemon API (`127.0.0.1:41112`) which is already running when Tailscale is active.

## Acceptance Criteria — ✅ VERIFIED

- [x] **Device type detection working** — Detects desktop, mobile, tablet, laptop, unknown
- [x] **Network state tracking** — Tracks WiFi, cellular, other, offline with real-time updates
- [x] **Tailscale integration ready** — Discovers peers, finds desktop, constructs Hermes URLs
- [x] **Tests passing** — 42 tests across 3 test suites, all passing

## Files Modified/Created

### Created
- `lib/services/device_awareness_service.dart` (362 lines)
- `lib/services/tailscale_integration_service.dart` (272 lines)
- `test/services/device_awareness_service_test.dart` (216 lines)
- `test/services/tailscale_integration_service_test.dart` (172 lines)
- `test/services/device_awareness_integration_test.dart` (200 lines)

### Modified
- `lib/services/router_server.dart` — Added 4 new endpoints + imports
- `pubspec.yaml` — Added `connectivity_plus: ^6.1.0`

## Next Steps

1. **Mobile UI Integration** — Adapt UI based on device type (e.g., single-column layout for phones)
2. **Response Personalization** — Use time-of-day to suggest appropriate response lengths
3. **Location Services** — Integrate GPS for location-aware context
4. **Offline Mode** — Queue requests when offline, sync when reconnected
5. **Tailscale Relay Service** — Enhance the existing Node.js relay with better error handling

---

**Completed:** November 10, 2026 21:28 EST
**Status:** ✅ **READY FOR MERGE**
