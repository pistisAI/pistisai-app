#include "platform_channels.h"

#include <windows.h>
#include <comdef.h>
#include <comutil.h>
#include <gdiplus.h>
#include <shlobj.h>
#include <shellapi.h>
#include <wincodec.h>
#include <wrl/client.h>

#include <algorithm>
#include <cstdio>
#include <fstream>
#include <iostream>
#include <memory>
#include <sstream>
#include <string>
#include <vector>

#pragma comment(lib, "gdiplus.lib")
#pragma comment(lib, "ole32.lib")
#pragma comment(lib, "oleaut32.lib")

using Microsoft::WRL::ComPtr;

// ============================================================================
// GDI+ Helper
// ============================================================================

static ULONG_PTR gdiplus_token = 0;
static bool gdiplus_initialized = false;

static bool init_gdiplus() {
  if (gdiplus_initialized) return true;

  Gdiplus::GdiplusStartupInput gdiplus_startup_input;
  Gdiplus::Status status = Gdiplus::GdiplusStartup(
      &gdiplus_token, &gdiplus_startup_input, nullptr);
  gdiplus_initialized = (status == Gdiplus::Ok);
  return gdiplus_initialized;
}

static void shutdown_gdiplus() {
  if (gdiplus_initialized) {
    Gdiplus::GdiplusShutdown(gdiplus_token);
    gdiplus_initialized = false;
  }
}

// ============================================================================
// Screenshot / Region Capture (pistisai/gui_automation, pistisai/region_capture)
// ============================================================================

static bool save_hbitmap_to_png(HBITMAP hBitmap, const std::string& path) {
  if (!init_gdiplus()) return false;

  Gdiplus::Bitmap bitmap(hBitmap, nullptr);
  CLSID png_clsid;
  CLSID encoder_clsid = {};

  // Get PNG encoder CLSID
  UINT num_encoders = 0;
  UINT size = 0;
  Gdiplus::GetImageEncodersSize(&num_encoders, &size);
  if (size == 0) return false;

  std::vector<Gdiplus::ImageCodecInfo> encoders(size);
  Gdiplus::GetImageEncoders(num_encoders, size, encoders.data());

  for (UINT i = 0; i < num_encoders; i++) {
    if (wcscmp(encoders[i].MimeType, L"image/png") == 0) {
      encoder_clsid = encoders[i].Clsid;
      break;
    }
  }

  if (encoder_clsid.Data1 == 0) return false;

  std::wstring wpath(path.begin(), path.end());
  Gdiplus::Status status = bitmap.Save(wpath.c_str(), &encoder_clsid, nullptr);
  return status == Gdiplus::Ok;
}

static flutter::EncodableValue capture_screenshot(
    const flutter::EncodableValue* args) {
  std::string path;
  if (args && std::holds_alternative<flutter::EncodableMap>(*args)) {
    auto map = std::get<flutter::EncodableMap>(*args);
    auto it = map.find(flutter::EncodableValue("path"));
    if (it != map.end() &&
        std::holds_alternative<std::string>(it->second)) {
      path = std::get<std::string>(it->second);
    }
  }

  if (path.empty()) {
    return flutter::EncodableValue(false);
  }

  HDC hdc_screen = GetDC(nullptr);
  HDC hdc_mem = CreateCompatibleDC(hdc_screen);

  int width = GetDeviceCaps(hdc_screen, HORZRES);
  int height = GetDeviceCaps(hdc_screen, VERTRES);

  HBITMAP hBitmap =
      CreateCompatibleBitmap(hdc_screen, width, height);
  SelectObject(hdc_mem, hBitmap);

  BitBlt(hdc_mem, 0, 0, width, height, hdc_screen, 0, 0, SRCCOPY);

  bool success = save_hbitmap_to_png(hBitmap, path);

  DeleteObject(hBitmap);
  DeleteDC(hdc_mem);
  ReleaseDC(nullptr, hdc_screen);

  return flutter::EncodableValue(success);
}

static flutter::EncodableValue capture_region(
    const flutter::EncodableValue* args) {
  int x = 0, y = 0, width = 0, height = 0;
  std::string path;

  if (args && std::holds_alternative<flutter::EncodableMap>(*args)) {
    auto map = std::get<flutter::EncodableMap>(*args);
    auto it_x = map.find(flutter::EncodableValue("x"));
    auto it_y = map.find(flutter::EncodableValue("y"));
    auto it_w = map.find(flutter::EncodableValue("width"));
    auto it_h = map.find(flutter::EncodableValue("height"));
    auto it_p = map.find(flutter::EncodableValue("path"));

    if (it_x != map.end() && std::holds_alternative<int>(it_x->second))
      x = std::get<int>(it_x->second);
    if (it_y != map.end() && std::holds_alternative<int>(it_y->second))
      y = std::get<int>(it_y->second);
    if (it_w != map.end() && std::holds_alternative<int>(it_w->second))
      width = std::get<int>(it_w->second);
    if (it_h != map.end() && std::holds_alternative<int>(it_h->second))
      height = std::get<int>(it_h->second);
    if (it_p != map.end() && std::holds_alternative<std::string>(it_p->second))
      path = std::get<std::string>(it_p->second);
  }

  if (path.empty() || width <= 0 || height <= 0) {
    return flutter::EncodableValue(false);
  }

  HDC hdc_screen = GetDC(nullptr);
  HDC hdc_mem = CreateCompatibleDC(hdc_screen);
  HBITMAP hBitmap = CreateCompatibleBitmap(hdc_screen, width, height);
  SelectObject(hdc_mem, hBitmap);

  BitBlt(hdc_mem, 0, 0, width, height, hdc_screen, x, y, SRCCOPY);

  bool success = save_hbitmap_to_png(hBitmap, path);

  DeleteObject(hBitmap);
  DeleteDC(hdc_mem);
  ReleaseDC(nullptr, hdc_screen);

  return flutter::EncodableValue(success);
}

static flutter::EncodableValue get_screen_size() {
  HDC hdc_screen = GetDC(nullptr);
  int width = GetDeviceCaps(hdc_screen, HORZRES);
  int height = GetDeviceCaps(hdc_screen, VERTRES);
  ReleaseDC(nullptr, hdc_screen);

  flutter::EncodableMap result;
  result[flutter::EncodableValue("width")] = flutter::EncodableValue(width);
  result[flutter::EncodableValue("height")] = flutter::EncodableValue(height);
  return flutter::EncodableValue(result);
}

static flutter::EncodableValue initialize_region_capture() {
  return flutter::EncodableValue(true);
}

// ============================================================================
// Camera Capture Channel (pistisai/camera_capture)
// ============================================================================

static flutter::EncodableValue camera_initialize() {
  // On Windows, camera access is handled by the camera plugin.
  // This channel provides a native wrapper for future camera operations.
  return flutter::EncodableValue(true);
}

static flutter::EncodableValue camera_list_cameras() {
  // Camera enumeration is handled by the camera plugin on the Dart side.
  flutter::EncodableList result;
  return flutter::EncodableValue(result);
}

static flutter::EncodableValue camera_capture_image(
    const flutter::EncodableValue* args) {
  // Camera image capture is delegated to the camera plugin.
  return flutter::EncodableValue(false);
}

// ============================================================================
// OCR Engine Channel (pistisai/ocr_engine)
// ============================================================================

static flutter::EncodableValue ocr_initialize() {
  // Check if tesseract is available on the system
  int ret = system("where tesseract > nul 2>&1");
  if (ret == 0) {
    std::cout << "[OCR] Tesseract binary found on system" << std::endl;
    return flutter::EncodableValue(true);
  }
  std::cerr << "[OCR] Tesseract binary not found on system" << std::endl;
  return flutter::EncodableValue(false);
}

static flutter::EncodableValue ocr_extract_text(
    const flutter::EncodableValue* args) {
  std::string image_path;

  if (args && std::holds_alternative<flutter::EncodableMap>(*args)) {
    auto map = std::get<flutter::EncodableMap>(*args);
    auto it = map.find(flutter::EncodableValue("imagePath"));
    if (it != map.end() &&
        std::holds_alternative<std::string>(it->second)) {
      image_path = std::get<std::string>(it->second);
    }
  }

  if (image_path.empty()) {
    return flutter::EncodableValue("");
  }

  // Build and execute tesseract command
  std::string cmd = "tesseract \"";
  cmd += image_path;
  cmd += "\" stdout -l eng 2>nul";

  FILE* pipe = _popen(cmd.c_str(), "r");
  if (!pipe) {
    std::cerr << "[OCR] Failed to run tesseract" << std::endl;
    return flutter::EncodableValue("");
  }

  std::string result;
  char buffer[4096];
  while (fgets(buffer, sizeof(buffer), pipe) != nullptr) {
    result += buffer;
  }
  _pclose(pipe);

  // Trim trailing newline
  while (!result.empty() &&
         (result.back() == '\n' || result.back() == '\r')) {
    result.pop_back();
  }

  return flutter::EncodableValue(result);
}

static flutter::EncodableValue ocr_extract_text_multilingual(
    const flutter::EncodableValue* args) {
  std::string image_path;
  std::string lang = "eng";

  if (args && std::holds_alternative<flutter::EncodableMap>(*args)) {
    auto map = std::get<flutter::EncodableMap>(*args);
    auto it_p = map.find(flutter::EncodableValue("imagePath"));
    if (it_p != map.end() &&
        std::holds_alternative<std::string>(it_p->second)) {
      image_path = std::get<std::string>(it_p->second);
    }

    auto it_l = map.find(flutter::EncodableValue("languages"));
    if (it_l != map.end() &&
        std::holds_alternative<flutter::EncodableList>(it_l->second)) {
      auto langs = std::get<flutter::EncodableList>(it_l->second);
      lang = "";
      for (const auto& item : langs) {
        if (std::holds_alternative<std::string>(item)) {
          if (!lang.empty()) lang += "+";
          lang += std::get<std::string>(item);
        }
      }
      if (lang.empty()) lang = "eng";
    }
  }

  if (image_path.empty()) {
    return flutter::EncodableValue("");
  }

  std::string cmd = "tesseract \"";
  cmd += image_path;
  cmd += "\" stdout -l ";
  cmd += lang;
  cmd += " 2>nul";

  FILE* pipe = _popen(cmd.c_str(), "r");
  if (!pipe) {
    std::cerr << "[OCR] Failed to run tesseract" << std::endl;
    return flutter::EncodableValue("");
  }

  std::string result;
  char buffer[4096];
  while (fgets(buffer, sizeof(buffer), pipe) != nullptr) {
    result += buffer;
  }
  _pclose(pipe);

  while (!result.empty() &&
         (result.back() == '\n' || result.back() == '\r')) {
    result.pop_back();
  }

  return flutter::EncodableValue(result);
}

static flutter::EncodableValue ocr_dispose() {
  return flutter::EncodableValue(true);
}

// ============================================================================
// Window Manager Channel (pistisai/window_manager)
// ============================================================================

struct WindowInfo {
  std::string id;
  std::string title;
  std::string app_name;
  int x;
  int y;
  int width;
  int height;
  bool is_minimized;
  bool is_maximized;
  bool is_active;
};

static BOOL CALLBACK enum_windows_proc(HWND hwnd, LPARAM lparam) {
  auto* windows = reinterpret_cast<std::vector<WindowInfo>*>(lparam);

  if (!IsWindowVisible(hwnd) || IsIconic(hwnd)) return TRUE;

  char title[256];
  GetWindowTextA(hwnd, title, sizeof(title));
  if (strlen(title) == 0) return TRUE;

  RECT rect;
  GetWindowRect(hwnd, &rect);

  char class_name[256];
  GetClassNameA(hwnd, class_name, sizeof(class_name));

  WindowInfo info;
  info.id = std::to_string(reinterpret_cast<uintptr_t>(hwnd));
  info.title = title;
  info.app_name = class_name;
  info.x = rect.left;
  info.y = rect.top;
  info.width = rect.right - rect.left;
  info.height = rect.bottom - rect.top;
  info.is_minimized = IsIconic(hwnd) ? true : false;
  info.is_maximized = IsZoomed(hwnd) ? true : false;
  info.is_active = (hwnd == GetForegroundWindow());

  windows->push_back(info);
  return TRUE;
}

static flutter::EncodableValue get_windows() {
  std::vector<WindowInfo> windows;
  EnumWindows(enum_windows_proc, reinterpret_cast<LPARAM>(&windows));

  flutter::EncodableList result;
  for (const auto& w : windows) {
    flutter::EncodableMap win_map;
    win_map[flutter::EncodableValue("id")] =
        flutter::EncodableValue(w.id);
    win_map[flutter::EncodableValue("title")] =
        flutter::EncodableValue(w.title);
    win_map[flutter::EncodableValue("appName")] =
        flutter::EncodableValue(w.app_name);
    win_map[flutter::EncodableValue("x")] =
        flutter::EncodableValue(w.x);
    win_map[flutter::EncodableValue("y")] =
        flutter::EncodableValue(w.y);
    win_map[flutter::EncodableValue("width")] =
        flutter::EncodableValue(w.width);
    win_map[flutter::EncodableValue("height")] =
        flutter::EncodableValue(w.height);
    win_map[flutter::EncodableValue("isMinimized")] =
        flutter::EncodableValue(w.is_minimized);
    win_map[flutter::EncodableValue("isMaximized")] =
        flutter::EncodableValue(w.is_maximized);
    win_map[flutter::EncodableValue("isActive")] =
        flutter::EncodableValue(w.is_active);
    result.push_back(flutter::EncodableValue(win_map));
  }

  return flutter::EncodableValue(result);
}

static flutter::EncodableValue focus_window(
    const flutter::EncodableValue* args) {
  std::string window_id;
  if (args && std::holds_alternative<flutter::EncodableMap>(*args)) {
    auto map = std::get<flutter::EncodableMap>(*args);
    auto it = map.find(flutter::EncodableValue("windowId"));
    if (it != map.end() &&
        std::holds_alternative<std::string>(it->second)) {
      window_id = std::get<std::string>(it->second);
    }
  }

  if (window_id.empty()) return flutter::EncodableValue(false);

  HWND hwnd = reinterpret_cast<HWND>(
      static_cast<uintptr_t>(std::stoull(window_id)));
  SetForegroundWindow(hwnd);
  return flutter::EncodableValue(true);
}

static flutter::EncodableValue move_window(
    const flutter::EncodableValue* args) {
  std::string window_id;
  int x = 0, y = 0;

  if (args && std::holds_alternative<flutter::EncodableMap>(*args)) {
    auto map = std::get<flutter::EncodableMap>(*args);
    auto it_id = map.find(flutter::EncodableValue("windowId"));
    auto it_x = map.find(flutter::EncodableValue("x"));
    auto it_y = map.find(flutter::EncodableValue("y"));
    if (it_id != map.end() &&
        std::holds_alternative<std::string>(it_id->second))
      window_id = std::get<std::string>(it_id->second);
    if (it_x != map.end() && std::holds_alternative<int>(it_x->second))
      x = std::get<int>(it_x->second);
    if (it_y != map.end() && std::holds_alternative<int>(it_y->second))
      y = std::get<int>(it_y->second);
  }

  if (window_id.empty()) return flutter::EncodableValue(false);

  HWND hwnd = reinterpret_cast<HWND>(
      static_cast<uintptr_t>(std::stoull(window_id)));
  SetWindowPos(hwnd, nullptr, x, y, 0, 0,
               SWP_NOSIZE | SWP_NOZORDER);
  return flutter::EncodableValue(true);
}

static flutter::EncodableValue resize_window(
    const flutter::EncodableValue* args) {
  std::string window_id;
  int width = 0, height = 0;

  if (args && std::holds_alternative<flutter::EncodableMap>(*args)) {
    auto map = std::get<flutter::EncodableMap>(*args);
    auto it_id = map.find(flutter::EncodableValue("windowId"));
    auto it_w = map.find(flutter::EncodableValue("width"));
    auto it_h = map.find(flutter::EncodableValue("height"));
    if (it_id != map.end() &&
        std::holds_alternative<std::string>(it_id->second))
      window_id = std::get<std::string>(it_id->second);
    if (it_w != map.end() && std::holds_alternative<int>(it_w->second))
      width = std::get<int>(it_w->second);
    if (it_h != map.end() && std::holds_alternative<int>(it_h->second))
      height = std::get<int>(it_h->second);
  }

  if (window_id.empty()) return flutter::EncodableValue(false);

  HWND hwnd = reinterpret_cast<HWND>(
      static_cast<uintptr_t>(std::stoull(window_id)));
  SetWindowPos(hwnd, nullptr, 0, 0, width, height,
               SWP_NOMOVE | SWP_NOZORDER);
  return flutter::EncodableValue(true);
}

static flutter::EncodableValue minimize_window(
    const flutter::EncodableValue* args) {
  std::string window_id;
  if (args && std::holds_alternative<flutter::EncodableMap>(*args)) {
    auto map = std::get<flutter::EncodableMap>(*args);
    auto it = map.find(flutter::EncodableValue("windowId"));
    if (it != map.end() &&
        std::holds_alternative<std::string>(it->second))
      window_id = std::get<std::string>(it->second);
  }

  if (window_id.empty()) return flutter::EncodableValue(false);

  HWND hwnd = reinterpret_cast<HWND>(
      static_cast<uintptr_t>(std::stoull(window_id)));
  ShowWindow(hwnd, SW_MINIMIZE);
  return flutter::EncodableValue(true);
}

static flutter::EncodableValue maximize_window(
    const flutter::EncodableValue* args) {
  std::string window_id;
  if (args && std::holds_alternative<flutter::EncodableMap>(*args)) {
    auto map = std::get<flutter::EncodableMap>(*args);
    auto it = map.find(flutter::EncodableValue("windowId"));
    if (it != map.end() &&
        std::holds_alternative<std::string>(it->second))
      window_id = std::get<std::string>(it->second);
  }

  if (window_id.empty()) return flutter::EncodableValue(false);

  HWND hwnd = reinterpret_cast<HWND>(
      static_cast<uintptr_t>(std::stoull(window_id)));
  ShowWindow(hwnd, SW_MAXIMIZE);
  return flutter::EncodableValue(true);
}

static flutter::EncodableValue toggle_maximize(
    const flutter::EncodableValue* args) {
  std::string window_id;
  if (args && std::holds_alternative<flutter::EncodableMap>(*args)) {
    auto map = std::get<flutter::EncodableMap>(*args);
    auto it = map.find(flutter::EncodableValue("windowId"));
    if (it != map.end() &&
        std::holds_alternative<std::string>(it->second))
      window_id = std::get<std::string>(it->second);
  }

  if (window_id.empty()) return flutter::EncodableValue(false);

  HWND hwnd = reinterpret_cast<HWND>(
      static_cast<uintptr_t>(std::stoull(window_id)));
  if (IsZoomed(hwnd)) {
    ShowWindow(hwnd, SW_RESTORE);
  } else {
    ShowWindow(hwnd, SW_MAXIMIZE);
  }
  return flutter::EncodableValue(true);
}

static flutter::EncodableValue close_window(
    const flutter::EncodableValue* args) {
  std::string window_id;
  if (args && std::holds_alternative<flutter::EncodableMap>(*args)) {
    auto map = std::get<flutter::EncodableMap>(*args);
    auto it = map.find(flutter::EncodableValue("windowId"));
    if (it != map.end() &&
        std::holds_alternative<std::string>(it->second))
      window_id = std::get<std::string>(it->second);
  }

  if (window_id.empty()) return flutter::EncodableValue(false);

  HWND hwnd = reinterpret_cast<HWND>(
      static_cast<uintptr_t>(std::stoull(window_id)));
  PostMessage(hwnd, WM_CLOSE, 0, 0);
  return flutter::EncodableValue(true);
}

// ============================================================================
// GUI Automation Channel (pistisai/gui_automation)
// ============================================================================

static flutter::EncodableValue execute_action(
    const flutter::EncodableValue* args) {
  std::string action;
  if (args && std::holds_alternative<flutter::EncodableMap>(*args)) {
    auto map = std::get<flutter::EncodableMap>(*args);
    auto it = map.find(flutter::EncodableValue("action"));
    if (it != map.end() &&
        std::holds_alternative<std::string>(it->second)) {
      action = std::get<std::string>(it->second);
    }
  }

  if (action.empty()) {
    return flutter::EncodableValue("No action specified");
  }

  bool success = false;

  if (action.find("click(") == 0) {
    size_t start = action.find("(");
    size_t comma = action.find(",");
    size_t end = action.find(")");

    if (start != std::string::npos && comma != std::string::npos &&
        end != std::string::npos) {
      int x = std::stoi(action.substr(start + 1, comma - start - 1));
      int y = std::stoi(action.substr(comma + 1, end - comma - 1));

      SetCursorPos(x, y);
      mouse_event(MOUSEEVENTF_LEFTDOWN, 0, 0, 0, 0);
      mouse_event(MOUSEEVENTF_LEFTUP, 0, 0, 0, 0);
      success = true;
    }
  } else if (action.find("keypress(") == 0) {
    size_t start = action.find("(");
    size_t end = action.find(")");

    if (start != std::string::npos && end != std::string::npos) {
      std::string key = action.substr(start + 1, end - start - 1);

      SHORT vk = 0;
      if (key == "Enter")
        vk = VK_RETURN;
      else if (key == "Tab")
        vk = VK_TAB;
      else if (key == "Escape")
        vk = VK_ESCAPE;
      else if (key == "Backspace")
        vk = VK_BACK;
      else if (key == "Delete")
        vk = VK_DELETE;
      else if (key == "space")
        vk = VK_SPACE;
      else if (key.length() == 1)
        vk = VkKeyScanA(key[0]);

      if (vk != 0) {
        keybd_event(vk, 0, 0, 0);
        keybd_event(vk, 0, KEYEVENTF_KEYUP, 0);
        success = true;
      }
    }
  } else if (action.find("scroll(") == 0) {
    size_t start = action.find("(");
    size_t end = action.find(")");

    if (start != std::string::npos && end != std::string::npos) {
      std::string direction =
          action.substr(start + 1, end - start - 1);

      int scroll_amount = 120;  // WHEEL_DELTA
      if (direction == "down") scroll_amount = -120;
      else if (direction == "up") scroll_amount = 120;
      else if (direction == "left") scroll_amount = -120;
      else if (direction == "right") scroll_amount = 120;

      // Use mouse_event for scroll (legacy but works everywhere)
      if (direction == "left" || direction == "right") {
        mouse_event(MOUSEEVENTF_HWHEEL, 0, 0,
                    scroll_amount, 0);
      } else {
        mouse_event(MOUSEEVENTF_WHEEL, 0, 0,
                    scroll_amount, 0);
      }
      success = true;
    }
  }

  return flutter::EncodableValue(
      success ? "Executed successfully" : "Execution failed");
}

// ============================================================================
// Method Call Handler
// ============================================================================

void PlatformChannelsMethodCallHandler(
    const std::string& method,
    std::unique_ptr<flutter::MethodCall<flutter::EncodableValue>> method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const auto* args =
      method_call->arguments()
          ? std::get_if<flutter::EncodableValue>(method_call->arguments())
          : nullptr;

  flutter::EncodableValue response;

  if (method == "takeScreenshot") {
    response = capture_screenshot(args);
  } else if (method == "executeAction") {
    response = execute_action(args);
  } else if (method == "captureRegion") {
    response = capture_region(args);
  } else if (method == "getScreenSize") {
    response = get_screen_size();
  } else if (method == "initialize") {
    response = initialize_region_capture();
  } else if (method == "getWindows") {
    response = get_windows();
  } else if (method == "focusWindow") {
    response = focus_window(args);
  } else if (method == "moveWindow") {
    response = move_window(args);
  } else if (method == "resizeWindow") {
    response = resize_window(args);
  } else if (method == "minimizeWindow") {
    response = minimize_window(args);
  } else if (method == "maximizeWindow") {
    response = maximize_window(args);
  } else if (method == "toggleMaximize") {
    response = toggle_maximize(args);
  } else if (method == "closeWindow") {
    response = close_window(args);
  } else if (method == "cameraInitialize") {
    response = camera_initialize();
  } else if (method == "cameraListCameras") {
    response = camera_list_cameras();
  } else if (method == "cameraCaptureImage") {
    response = camera_capture_image(args);
  } else if (method == "ocrInitialize") {
    response = ocr_initialize();
  } else if (method == "ocrExtractText") {
    response = ocr_extract_text(args);
  } else if (method == "ocrExtractTextMultilingual") {
    response = ocr_extract_text_multilingual(args);
  } else if (method == "ocrDispose") {
    response = ocr_dispose();
  } else {
    result->NotImplemented();
    return;
  }

  result->Success(response);
}

// ============================================================================
// Registration
// ============================================================================

void RegisterPlatformChannels(flutter::PluginRegistrar* registrar) {
  auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      registrar->messenger(), "pistisai/gui_automation",
      &flutter::StandardMethodCodec::GetInstance());

  channel->SetMethodCallHandler(
      [](const auto& call, auto result) {
        PlatformChannelsMethodCallHandler(
            call.method_name(),
            std::move(const_cast<std::unique_ptr<flutter::MethodCall<flutter::EncodableValue>>&>(call)),
            std::move(result));
      });

  auto region_channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), "pistisai/region_capture",
          &flutter::StandardMethodCodec::GetInstance());

  region_channel->SetMethodCallHandler(
      [](const auto& call, auto result) {
        PlatformChannelsMethodCallHandler(
            call.method_name(),
            std::move(const_cast<std::unique_ptr<flutter::MethodCall<flutter::EncodableValue>>&>(call)),
            std::move(result));
      });

  auto window_channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), "pistisai/window_manager",
          &flutter::StandardMethodCodec::GetInstance());

  window_channel->SetMethodCallHandler(
      [](const auto& call, auto result) {
        PlatformChannelsMethodCallHandler(
            call.method_name(),
            std::move(const_cast<std::unique_ptr<flutter::MethodCall<flutter::EncodableValue>>&>(call)),
            std::move(result));
      });

  auto camera_channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), "pistisai/camera_capture",
          &flutter::StandardMethodCodec::GetInstance());

  camera_channel->SetMethodCallHandler(
      [](const auto& call, auto result) {
        PlatformChannelsMethodCallHandler(
            call.method_name(),
            std::move(const_cast<std::unique_ptr<flutter::MethodCall<flutter::EncodableValue>>&>(call)),
            std::move(result));
      });

  auto ocr_channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), "pistisai/ocr_engine",
          &flutter::StandardMethodCodec::GetInstance());

  ocr_channel->SetMethodCallHandler(
      [](const auto& call, auto result) {
        PlatformChannelsMethodCallHandler(
            call.method_name(),
            std::move(const_cast<std::unique_ptr<flutter::MethodCall<flutter::EncodableValue>>&>(call)),
            std::move(result));
      });

  // Channels are not plugins; release ownership so they live for the
  // process lifetime and their method-call handlers stay valid.
  (void)channel.release();
  (void)region_channel.release();
  (void)window_channel.release();
  (void)camera_channel.release();
  (void)ocr_channel.release();
}
