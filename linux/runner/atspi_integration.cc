#include "atspi_integration.h"

#include <gtk/gtk.h>
#include <gdk/gdk.h>
#ifdef GDK_WINDOWING_WAYLAND
#include <gdk/gdkwayland.h>
#endif
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif

#include <atspi/atspi.h>

void atspi_integration_init(void) {
  // Enable GTK accessibility explicitly
  // This environment variable tells GTK to build and maintain an accessibility tree
  g_setenv("GTK_ACCESSIBILITY", "1", TRUE);

  // Initialize AT-SPI 2.0 and register this application with the accessibility bus
  // This allows screen readers, automated testing tools, and other assistive technologies
  // to discover and interact with the application's UI elements
  if (!atspi_is_initialized()) {
    AtspiError* error = NULL;
    if (!atspi_init(&error)) {
      if (error) {
        g_warning("Failed to initialize AT-SPI 2.0: %s", error->message);
        g_error_free(error);
      } else {
        g_warning("Failed to initialize AT-SPI 2.0: unknown error");
      }
      // Continue anyway; the app will still function, just without accessibility
    } else {
      g_message("[Pistisai] AT-SPI 2.0 initialized successfully");
    }
  }
}

gboolean atspi_integration_is_wayland(void) {
  GdkDisplay* display = gdk_display_get_default();
  if (!display) {
    g_warning("Failed to get default display");
    return FALSE;
  }

#ifdef GDK_WINDOWING_WAYLAND
  return GDK_IS_WAYLAND_DISPLAY(display);
#else
  return FALSE;
#endif
}

void atspi_integration_configure_wayland_focus(GtkWindow* window) {
  if (!window) {
    g_warning("atspi_integration_configure_wayland_focus: window is NULL");
    return;
  }

  if (!atspi_integration_is_wayland()) {
    // Not running on Wayland; X11 focus handling is automatic
    return;
  }

  // On Wayland, the compositor manages focus differently than X11.
  // To ensure stable focus during operations:
  // 1. Mark window as requiring focus updates
  // 2. Present the window with explicit timestamp to grab initial focus
  // 3. Ensure the window is marked as focused for accessibility purposes

  // Don't keep the window above others by default; let the compositor manage stacking
  gtk_window_set_keep_above(window, FALSE);

  // Present the window with an explicit current time to ensure focus is captured
  // This is critical on Wayland where implicit focus may not work reliably
  gtk_window_present_with_time(window, GDK_CURRENT_TIME);

  // Mark window as needing focus updates; GTK will request focus from the compositor
  gtk_widget_grab_focus(GTK_WIDGET(window));

  g_message("[Pistisai] Wayland focus tracking configured");
}

void atspi_integration_log_status(void) {
  GdkDisplay* display = gdk_display_get_default();
  const char* display_name = display ? gdk_display_get_name(display) : "unknown";

  gboolean is_wayland = atspi_integration_is_wayland();
  const char* display_type = is_wayland ? "Wayland" : "X11";

  gboolean atspi_ok = atspi_is_initialized();

  g_message("[Pistisai] Display Server: %s (%s)", display_type, display_name);
  g_message("[Pistisai] AT-SPI 2.0: %s", atspi_ok ? "enabled" : "disabled");
  g_message("[Pistisai] GTK Accessibility: %s",
            g_getenv("GTK_ACCESSIBILITY") ? "enabled" : "disabled");
}
