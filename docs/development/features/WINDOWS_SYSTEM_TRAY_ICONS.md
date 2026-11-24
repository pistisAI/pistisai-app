# Windows System Tray Icons — ICO Format Support (PLANNED — not implemented)

> **Verified against code (2026-11-24):** this document describes a **planned** feature. `lib/services/native_tray_service.dart:136-146` (`_getTrayIconPath`) returns only **`.png`** paths for every status — `tray_icon_connected.png`, `tray_icon_connecting.png`, `tray_icon_disconnected.png` — with **no `Platform.isWindows` / `.ico` branch**. `git ls-files assets/images/tray*` lists exactly those three `.png` files; there are **no `.ico` assets** (no `tray_icon.ico`, `tray_icon_partial.ico`, etc.). `scripts/convert_icons_to_ico.py` exists, but nothing consumes its output. `test/services/native_tray_service_test.dart` does **not** exist. Everything below describes planned work, not current behavior.

## 📋 Overview

Pistisai currently uses PNG tray icons on all platforms. ICO format support with embedded multiple sizes is **planned**, not shipped.

## 🎯 Features

### **Multi-Size ICO Files**

- **16x16**: Standard system tray size
- **24x24**: High DPI displays
- **32x32**: Large icon mode
- **48x48**: Extra large displays

### **Platform-Specific Icon Selection (planned)**

- **Windows**: planned — use `.ico` files (NOT implemented; code uses `.png` for Windows too)
- **Linux/macOS**: current — `.png` files for all platforms
- **Automatic Detection**: planned — no `Platform.isWindows` branch exists in `_getTrayIconPath`

### **Connection Status Icons (actual: .png only)**

- **Connected**: `tray_icon_connected.png` — green indicator (`.ico` planned)
- **Disconnected**: `tray_icon_disconnected.png` — red indicator (`.ico` planned)
- **Connecting**: `tray_icon_connecting.png` — yellow indicator (`.ico` planned)
- **Partial**: no icon file exists (`.ico` and `.png` both planned)

## 🏗️ Implementation Details

### **Icon Path Logic**

```dart
String _getIconPath(TrayConnectionStatus status) {
  // Use .ico files on Windows for better system tray compatibility
  // Use .png files on other platforms (Linux, macOS)
  final extension = Platform.isWindows ? '.ico' : '.png';
  
  switch (status) {
    case TrayConnectionStatus.allConnected:
      return 'assets/images/tray_icon_connected$extension';
    // ... other cases
  }
}
```

### **Fallback Icon Support**

```dart
// Try with a fallback icon using platform-specific format
final fallbackExtension = Platform.isWindows ? '.ico' : '.png';
await trayManager.setIcon('assets/images/tray_icon$fallbackExtension');
```

## 📁 File Structure

```
assets/images/
├── tray_icon.ico                 # Generic fallback (Windows)
├── tray_icon.png                 # Generic fallback (Linux/macOS)
├── tray_icon_connected.ico       # Connected state (Windows)
├── tray_icon_connected.png       # Connected state (Linux/macOS)
├── tray_icon_disconnected.ico    # Disconnected state (Windows)
├── tray_icon_disconnected.png    # Disconnected state (Linux/macOS)
├── tray_icon_connecting.ico      # Connecting state (Windows)
├── tray_icon_connecting.png      # Connecting state (Linux/macOS)
├── tray_icon_partial.ico         # Partial connection (Windows)
└── tray_icon_partial.png         # Partial connection (Linux/macOS)
```

## 🔧 Icon Generation

### **Conversion Script**

The project includes `scripts/convert_icons_to_ico.py` for converting PNG icons to ICO format:

```bash
python scripts/convert_icons_to_ico.py
```

### **ICO File Specifications**

- **Format**: Windows ICO with embedded multiple sizes
- **Sizes**: 16x16, 24x24, 32x32, 48x48 pixels
- **Color Depth**: 32-bit RGBA for transparency support
- **Compression**: Optimized for file size while maintaining quality

## 🎨 Design Guidelines

### **Icon Design Principles**

- **Clarity**: Icons remain clear at 16x16 pixels
- **Contrast**: High contrast for visibility in both light and dark themes
- **Consistency**: Unified design language across all connection states
- **Branding**: Uses Pistisai visual identity

### **Theme Compatibility**

- **Light Theme**: Icons designed for light system tray backgrounds
- **Dark Theme**: Sufficient contrast for dark system tray backgrounds
- **High Contrast**: Accessible design for high contrast Windows themes

## 🧪 Testing

### **Automated Tests**

```bash
flutter test test/services/native_tray_service_test.dart
```

### **Manual Testing Checklist**

- [ ] Icons display correctly in Windows system tray
- [ ] All connection states show appropriate icons
- [ ] Icons scale properly on high DPI displays
- [ ] Fallback icons work when primary icons fail
- [ ] Icons remain visible in both light and dark Windows themes

## 🔄 Platform Abstraction

### **Cross-Platform Compatibility**

The implementation maintains the existing platform abstraction pattern:

```dart
// Platform detection using dart:io
static bool get isWindows => Platform.isWindows;
static bool get isLinux => Platform.isLinux;
static bool get isMacOS => Platform.isMacOS;
```

### **Consistent API**

The same `NativeTrayService` API works across all platforms while using platform-optimized icon formats internally.

## 📦 Asset Management

### **pubspec.yaml Configuration**

```yaml
flutter:
  assets:
    - assets/images/  # Includes both .png and .ico files
```

### **Build Integration**

ICO files are automatically included in Windows builds and available at runtime through the Flutter asset system.

## 🚀 Benefits

1. **Native Windows Experience**: ICO format provides optimal Windows system tray integration
2. **Multi-DPI Support**: Embedded multiple sizes ensure crisp display at any scale
3. **Performance**: Optimized file sizes for faster loading
4. **Maintainability**: Automated conversion process for easy updates
5. **Cross-Platform**: Maintains compatibility with Linux and macOS

## 🔮 Future Enhancements

- **Animated Icons**: Support for animated ICO files for connection states
- **Theme-Aware Icons**: Automatic icon selection based on Windows theme
- **Custom Icon Sets**: User-configurable icon themes
- **SVG Support**: Vector-based icons for infinite scalability
