#ifndef PISTISAI_ATSPI_INTEGRATION_H
#define PISTISAI_ATSPI_INTEGRATION_H

#include <glib.h>
#include <gdk/gdk.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * Initialize AT-SPI accessibility tree.
 * This function:
 * - Enables GTK accessibility
 * - Registers the application with AT-SPI registry via DBus
 * - Ensures all UI elements expose their semantic meaning to assistive technologies
 *
 * Must be called during application startup, before the main window is displayed.
 */
void atspi_integration_init(void);

/**
 * Detect if the application is running on Wayland compositor.
 *
 * @return TRUE if running on Wayland, FALSE on X11
 */
gboolean atspi_integration_is_wayland(void);

/**
 * Configure Wayland-specific focus handling.
 * This function ensures focus is properly tracked on Wayland,
 * avoiding focus loss during async operations.
 *
 * @param window The main GTK application window
 */
void atspi_integration_configure_wayland_focus(GtkWindow* window);

/**
 * Log the current display server and accessibility status.
 */
void atspi_integration_log_status(void);

#ifdef __cplusplus
}
#endif

#endif  // PISTISAI_ATSPI_INTEGRATION_H
