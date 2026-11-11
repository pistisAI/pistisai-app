# Linux Desktop Integration Files

This directory contains files required for Linux desktop integration and Flatpak packaging.

## Files

### Desktop entry
Desktop entry file that provides application menu integration on Linux systems.

**Purpose**: 
- Adds Pistisai to application menus
- Defines application name, icon, and categories
- Specifies how to launch the application

**Location in Flatpak**: `/app/share/applications/`

**Specification**: [Desktop Entry Specification](https://specifications.freedesktop.org/desktop-entry-spec/latest/)

### AppStream metadata
AppStream metadata file that provides information for software centers.

**Purpose**:
- Displays application information in software centers (GNOME Software, KDE Discover, etc.)
- Provides description, screenshots, and release information
- Enables better discoverability

**Location in Flatpak**: `/app/share/metainfo/`

**Specification**: [AppStream Metadata](https://www.freedesktop.org/software/appstream/docs/)

## Usage

These files are included when building the Flatpak package from the manifest in this directory.

## Testing Desktop Integration

After installing the Flatpak, you can verify desktop integration:

```bash
# Check if the desktop file is installed
flatpak run --command=ls <flatpak-id> /app/share/applications/

# Check if the metadata is installed
flatpak run --command=ls <flatpak-id> /app/share/metainfo/

# Validate the desktop entry and AppStream metadata in this directory
desktop-file-validate linux/*.desktop
appstreamcli validate linux/*.metainfo.xml
```

## Updating

When updating these files:

1. **Desktop file**: Update Name, Comment, or Categories as needed
2. **Metadata file**: Add new release entries when publishing new versions
3. **Test changes**: Validate files before committing
4. **Rebuild Flatpak**: Changes require rebuilding the Flatpak package

## References

- [Desktop Entry Specification](https://specifications.freedesktop.org/desktop-entry-spec/latest/)
- [AppStream Documentation](https://www.freedesktop.org/software/appstream/docs/)
- [Flatpak Documentation](https://docs.flatpak.org/)
- [Freedesktop Standards](https://www.freedesktop.org/wiki/Specifications/)
