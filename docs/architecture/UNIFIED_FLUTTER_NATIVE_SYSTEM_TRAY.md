# Pistisai Unified Flutter-Native Architecture - System Tray Implementation

## 📋 Overview

Pistisai implements a Unified Flutter-Native Architecture with integrated system tray functionality that provides cross-platform system tray integration with connection status monitoring. (The earlier "v3.10.3+" version marker was stale; the current app version is `1.5.58+180` per `pubspec.yaml:6`.)

**Key Features:**

- **Native Flutter Integration**: Direct integration using `tray_manager` package
- **Real-Time Status Updates**: Live connection monitoring with visual indicators
- **Cross-Platform Support**: Consistent behavior across Linux, Windows, and macOS
- **Unified Architecture**: Integrated within main Flutter application
- **Zero External Dependencies**: No separate daemon processes required

---

## 🏗️ **Architecture Components**

### **1. Native Tray Service**

**Location**: `lib/services/native_tray_service.dart`

**Core Functionality**:

- System tray initialization and management
- Icon state management based on connection status
- Context menu creation and event handling
- Integration with the app's `ConnectionManagerService` (no `TunnelManagerService` exists)
- Platform-specific behavior adaptation

**Key Methods**:

```dart
class NativeTrayService with TrayListener {
  Future<bool> initialize({
    ConnectionManagerService? connectionManager,
    void Function()? onShowWindow,
    void Function()? onHideWindow,
    void Function()? onSettings,
    void Function()? onQuit,
  });
  
  Future<void> updateConnectionStatus(TrayConnectionStatus status);
  Future<void> updateTooltip(String text);
  Future<void> dispose();
}
```

### **2. Connection Status Integration**

**Status Types** (actual enum in `lib/services/native_tray_service.dart:9-14`):

- `TrayConnectionStatus.allConnected` - Green indicator, all configured connections healthy
- `TrayConnectionStatus.partiallyConnected` - Partial connection state
- `TrayConnectionStatus.connecting` - Yellow indicator, establishing connection
- `TrayConnectionStatus.disconnected` - Red indicator, no connection

The service no longer tracks Ollama: its own source states "Ollama integration removed. Uses ConnectionManagerService only" (`native_tray_service.dart:19`). There is no `error` status in the current enum.

**Real-Time Updates**:

- Direct integration with `ConnectionManagerService`
- Automatic status propagation to system tray
- Visual feedback without user intervention
- Health monitoring with automatic reconnection

### **3. Context Menu System**

**Menu Structure**:

```dart
Menu(
  items: [
    MenuItem(key: 'show', label: 'Show Pistisai'),
    MenuItem(key: 'hide', label: 'Hide to Tray'),
    MenuItem.separator(),
    MenuItem(key: 'status', label: 'Connection Status'),
    MenuItem(key: 'settings', label: 'Settings'),
    MenuItem.separator(),
    MenuItem(key: 'quit', label: 'Quit'),
  ],
)
```

**Event Handling**:

- Direct callback integration with main application
- Window management through `WindowManagerService`
- Navigation integration for settings and status screens
- Graceful application shutdown

---

## 🖥️ **Platform-Specific Implementation**

### **Linux Support**

- **Desktop Environment Compatibility**: Works with GNOME, KDE, XFCE, i3, and others
- **Icon Theming**: Adaptive icons that respect system theme
- **Wayland Support**: Compatible with both X11 and Wayland sessions
- **System Requirements**: No additional dependencies required

### **Windows Support**

- **Native Integration**: Uses Windows system tray APIs
- **Theme Adaptation**: Automatically adapts to light/dark system themes
- **Version Compatibility**: Supports Windows 10 and later
- **Notification Area**: Standard Windows notification area behavior

### **macOS Support**

- **Menu Bar Integration**: Native macOS menu bar integration
- **System Preferences**: Respects macOS system tray preferences
- **Dark Mode**: Automatic adaptation to macOS dark mode
- **Accessibility**: Full accessibility support

---

## 🔄 **Integration with Main Application**

### **Initialization Process**

```dart
// In the app's tray initializer (native platforms only)
final nativeTray = NativeTrayService();
final success = await nativeTray.initialize(
  connectionManager: connectionManager, // resolved from the service locator
  onShowWindow: () => windowManager.showWindow(),
  onHideWindow: () => windowManager.hideToTray(),
  onSettings: () => navigateToSettings(),
  onQuit: () => exitApplication(),
);
```

`NativeTrayService` is a singleton (`NativeTrayService()`) that adds itself as a listener on the injected `ConnectionManagerService` (`lib/services/native_tray_service.dart:43-47,83-92`).

### **Status Update Flow**

1. `ConnectionManagerService` detects connection change
2. Service broadcasts status update
3. `NativeTrayService` receives update via listener
4. Tray icon and tooltip updated automatically
5. User sees real-time visual feedback

### **Window Management Integration**

- **Show/Hide Functionality**: Seamless window visibility control
- **Minimize to Tray**: Application hides to system tray instead of taskbar
- **Restore from Tray**: Click tray icon to restore window
- **Focus Management**: Proper window focus and activation

---

## ⚡ **Performance Characteristics**

### **Resource Usage**

- **Memory Overhead**: Minimal additional memory usage (~1-2MB)
- **CPU Impact**: Negligible CPU usage for status updates
- **Startup Time**: No additional startup delay
- **Battery Impact**: No measurable battery drain

### **Reliability Features**

- **Graceful Degradation**: Application continues if tray unavailable
- **Error Recovery**: Automatic recovery from tray initialization failures
- **Platform Detection**: Automatic platform capability detection
- **Fallback Behavior**: Standard window behavior when tray unsupported

---

## 🔧 **Development and Testing**

### **Local Development**

```bash
# Run with system tray enabled on a desktop platform
flutter run -d linux

# Native tray is disabled automatically on web (kIsWeb guard in
# lib/services/native_tray_service.dart:57-61); there is no
# DISABLE_SYSTEM_TRAY environment flag in the codebase.
```

There is currently **no native tray service test** in the repository. The "Testing Scenarios" list below describes target coverage, not tests that exist today; tray coverage is therefore still planned work.

### **Debug Information**

```dart
// Enable debug logging
debugPrint('🖥️ [NativeTray] Initializing native tray service...');
debugPrint('🖥️ [NativeTray] Tray icon clicked');
debugPrint('🖥️ [NativeTray] Menu item clicked: ${menuItem.key}');
```

### **Testing Scenarios**

- System tray availability detection
- Icon state changes with connection status
- Context menu functionality
- Window show/hide operations
- Application shutdown from tray

---

## 🚀 **Benefits of Unified Flutter-Native Approach**

### **Development Benefits**

- **Single Codebase**: No separate daemon implementation required
- **Direct Integration**: No IPC communication complexity
- **Unified Testing**: Single application testing approach
- **Simplified Debugging**: All functionality in one process

### **User Experience Benefits**

- **Instant Updates**: Real-time status changes without delays
- **Native Behavior**: Platform-consistent tray behavior
- **Reliable Operation**: No daemon communication failures
- **Simplified Installation**: Single executable deployment

### **Maintenance Benefits**

- **Unified Updates**: Single application update process
- **Reduced Complexity**: No multi-process architecture
- **Consistent Logging**: All logs in single application
- **Simplified Support**: Single process for troubleshooting

---

This Unified Flutter-Native Architecture provides a robust, native, and user-friendly system tray experience while maintaining the simplicity and reliability of a unified Flutter application.
