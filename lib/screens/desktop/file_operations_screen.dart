import 'dart:io';
import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:pistisai/widgets/navigation/breadcrumb_bar.dart';

/// Screen for file operations (browse, copy, move, delete files)
///
/// Platform-specific: Works on desktop platforms (Linux, Windows).
/// Web shows a message indicating limited support.
class FileOperationsScreen extends StatefulWidget {
  const FileOperationsScreen({super.key});

  @override
  State<FileOperationsScreen> createState() => _FileOperationsScreenState();
}

class _FileOperationsScreenState extends State<FileOperationsScreen> {
  Directory _currentDirectory = Directory.current;
  List<FileSystemEntity> _items = [];
  bool _isLoading = true;

  /// Error raised while listing a directory, formatted in build so the
  /// message follows the current locale.
  Object? _loadError;

  AppLocalizations get _l10n => AppLocalizations.of(context);

  // Selection
  final Set<FileSystemEntity> _selectedItems = {};
  bool _isMultiSelectMode = false;

  // Clipboard for copy/move
  FileSystemEntity? _clipboardItem;
  String _clipboardAction = ''; // 'copy' or 'move'

  @override
  void initState() {
    super.initState();
    _loadDirectory(_currentDirectory);
  }

  /// Load directory contents
  Future<void> _loadDirectory(Directory directory) async {
    try {
      setState(() {
        _isLoading = true;
        _loadError = null;
      });

      final items = await directory.list().toList();

      // Sort: directories first, then files, alphabetically
      items.sort((a, b) {
        final aIsDir = a is Directory;
        final bIsDir = b is Directory;

        if (aIsDir && !bIsDir) return -1;
        if (!aIsDir && bIsDir) return 1;

        return a.path.toLowerCase().compareTo(b.path.toLowerCase());
      });

      if (mounted) {
        setState(() {
          _currentDirectory = directory;
          _items = items;
          _selectedItems.clear();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadError = e;
          _isLoading = false;
        });
      }
    }
  }

  /// Navigate to directory
  Future<void> _navigateTo(Directory directory) async {
    await _loadDirectory(directory);
  }

  /// Navigate up to parent
  Future<void> _navigateUp() async {
    final parent = _currentDirectory.parent;
    await _loadDirectory(parent);
  }

  /// Refresh current directory
  Future<void> _refresh() async {
    await _loadDirectory(_currentDirectory);
  }

  /// Create new directory
  Future<void> _createDirectory() async {
    final l10n = _l10n;
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.filesNewDirectory),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            decoration: InputDecoration(
              labelText: l10n.filesDirectoryName,
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.folder),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return l10n.filesDirectoryNameRequired;
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(context, true);
              }
            },
            child: Text(l10n.commonCreate),
          ),
        ],
      ),
    );

    if (confirmed == true && controller.text.trim().isNotEmpty) {
      try {
        final newDir =
            Directory('${_currentDirectory.path}/${controller.text.trim()}');
        await newDir.create();
        await _refresh();
      } catch (e) {
        _showErrorDialog(l10n.filesCreateDirectoryFailed('$e'));
      }
    }
  }

  /// Create new file
  Future<void> _createFile() async {
    final l10n = _l10n;
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.filesNewFile),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            decoration: InputDecoration(
              labelText: l10n.filesFileName,
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.description),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return l10n.filesFileNameRequired;
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(context, true);
              }
            },
            child: Text(l10n.commonCreate),
          ),
        ],
      ),
    );

    if (confirmed == true && controller.text.trim().isNotEmpty) {
      try {
        final newFile =
            File('${_currentDirectory.path}/${controller.text.trim()}');
        await newFile.create();
        await _refresh();
      } catch (e) {
        _showErrorDialog(l10n.filesCreateFileFailed('$e'));
      }
    }
  }

  /// Delete selected items
  Future<void> _deleteSelected() async {
    if (_selectedItems.isEmpty) return;
    final l10n = _l10n;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.filesConfirmDelete),
        content: Text(l10n.filesDeleteConfirm(_selectedItems.length)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.colorsOf(context).danger,
              foregroundColor: AppTheme.colorsOf(context).textColor,
            ),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        for (final item in _selectedItems) {
          if (item is Directory) {
            await item.delete(recursive: true);
          } else {
            await item.delete();
          }
        }
        await _refresh();
      } catch (e) {
        _showErrorDialog(l10n.filesDeleteFailed('$e'));
      }
    }
  }

  /// Copy selected item
  void _copySelected() {
    if (_selectedItems.length != 1) return;

    setState(() {
      _clipboardItem = _selectedItems.first;
      _clipboardAction = 'copy';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_l10n.filesCopied(_getItemName(_clipboardItem!))),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Move selected item
  void _moveSelected() {
    if (_selectedItems.length != 1) return;

    setState(() {
      _clipboardItem = _selectedItems.first;
      _clipboardAction = 'move';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_l10n.filesCut(_getItemName(_clipboardItem!))),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Paste clipboard item
  Future<void> _pasteClipboard() async {
    if (_clipboardItem == null) return;
    final l10n = _l10n;

    try {
      final destinationPath =
          '${_currentDirectory.path}/${_getItemName(_clipboardItem!)}';

      if (_clipboardAction == 'copy') {
        if (_clipboardItem is File) {
          await (_clipboardItem as File).copy(destinationPath);
        } else if (_clipboardItem is Directory) {
          await _copyDirectory(
            _clipboardItem as Directory,
            Directory(destinationPath),
          );
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.filesPasted),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else if (_clipboardAction == 'move') {
        await _clipboardItem!.rename(destinationPath);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.filesMoved),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }

      await _refresh();
    } catch (e) {
      _showErrorDialog(l10n.filesPasteFailed('$e'));
    }
  }

  /// Copy directory recursively
  Future<void> _copyDirectory(Directory source, Directory destination) async {
    if (!await destination.exists()) {
      await destination.create();
    }

    await for (final entity in source.list()) {
      final newPath = '${destination.path}/${_getItemName(entity)}';
      if (entity is File) {
        await entity.copy(newPath);
      } else if (entity is Directory) {
        await _copyDirectory(entity, Directory(newPath));
      }
    }
  }

  /// Rename item
  Future<void> _renameItem(FileSystemEntity item) async {
    final l10n = _l10n;
    final controller = TextEditingController(text: _getItemName(item));
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.filesRename),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            decoration: InputDecoration(
              labelText: l10n.filesNewName,
              border: const OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return l10n.filesNameRequired;
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(context, true);
              }
            },
            child: Text(l10n.filesRename),
          ),
        ],
      ),
    );

    if (confirmed == true && controller.text.trim().isNotEmpty) {
      try {
        final newPath = '${_currentDirectory.path}/${controller.text.trim()}';
        await item.rename(newPath);
        await _refresh();
      } catch (e) {
        _showErrorDialog(l10n.filesRenameFailed('$e'));
      }
    }
  }

  /// Get item name from path
  String _getItemName(FileSystemEntity item) {
    return item.path.split(Platform.pathSeparator).last;
  }

  /// Show error dialog
  void _showErrorDialog(String message) {
    if (!mounted) return;
    final l10n = _l10n;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.commonError),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.filesOk),
          ),
        ],
      ),
    );
  }

  /// Show item details
  void _showItemDetails(FileSystemEntity item) async {
    final l10n = _l10n;
    final stat = await item.stat();
    final size = stat.size;
    final modified = stat.modified;

    final sizeText = _formatSize(l10n, size);

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_getItemName(item)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _detailRow(context, Icons.description, l10n.commonType,
                item is Directory ? l10n.filesDirectory : l10n.filesFile),
            _detailRow(context, Icons.storage, l10n.filesSize, sizeText),
            _detailRow(context, Icons.access_time, l10n.filesModified,
                '${modified.day}/${modified.month}/${modified.year}'),
            _detailRow(context, Icons.folder, l10n.filesPath, item.path),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.commonClose),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(
      BuildContext context, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon,
              size: 18, color: AppTheme.colorsOf(context).textColorLight),
          const SizedBox(width: 12),
          Text(
            '${AppLocalizations.of(context).commonFieldLabel(label)} ',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Expanded(child: Text(value, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = _l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.filesTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
          tooltip: l10n.commonBack,
        ),
        actions: [
          if (_clipboardItem != null)
            IconButton(
              icon: const Icon(Icons.content_paste),
              onPressed: _pasteClipboard,
              tooltip: l10n.filesPaste,
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
            tooltip: l10n.commonRefresh,
          ),
          PopupMenuButton<String>(
            onSelected: (action) {
              switch (action) {
                case 'new_dir':
                  _createDirectory();
                  break;
                case 'new_file':
                  _createFile();
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'new_dir',
                child: ListTile(
                  leading: const Icon(Icons.create_new_folder),
                  title: Text(l10n.filesNewDirectory),
                ),
              ),
              PopupMenuItem(
                value: 'new_file',
                child: ListTile(
                  leading: const Icon(Icons.note_add),
                  title: Text(l10n.filesNewFile),
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          const AutoBreadcrumbBar(),
          // Path bar
          _buildPathBar(),

          // Selection actions
          if (_selectedItems.isNotEmpty) _buildSelectionActions(),

          // File list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _loadError != null
                    ? Center(child: Text(l10n.filesLoadFailed('$_loadError')))
                    : _buildFileList(),
          ),
        ],
      ),
    );
  }

  /// Build path bar
  Widget _buildPathBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Row(
        children: [
          Icon(Icons.folder_open, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Text(
                    _currentDirectory.path,
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                ],
              ),
            ),
          ),
          if (_currentDirectory.path != Directory.current.path)
            IconButton(
              icon: const Icon(Icons.home),
              onPressed: () => _loadDirectory(Directory.current),
              tooltip: _l10n.filesGoHome,
              constraints: const BoxConstraints(),
              padding: EdgeInsets.zero,
            ),
        ],
      ),
    );
  }

  /// Build selection actions bar
  Widget _buildSelectionActions() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Row(
        children: [
          Text(
            _l10n.filesSelected(_selectedItems.length),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSecondaryContainer,
                ),
          ),
          const Spacer(),
          if (_selectedItems.length == 1) ...[
            IconButton(
              icon: const Icon(Icons.content_copy),
              onPressed: _copySelected,
              tooltip: _l10n.filesCopy,
            ),
            IconButton(
              icon: const Icon(Icons.content_cut),
              onPressed: _moveSelected,
              tooltip: _l10n.filesMove,
            ),
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _renameItem(_selectedItems.first),
              tooltip: _l10n.filesRename,
            ),
          ],
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _deleteSelected,
            tooltip: _l10n.commonDelete,
            color: AppTheme.colorsOf(context).danger,
          ),
        ],
      ),
    );
  }

  /// Build file list
  Widget _buildFileList() {
    if (_items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.folder_open,
              size: 64,
              color: AppTheme.colorsOf(context)
                  .textColorLight
                  .withValues(alpha: 0.6),
            ),
            const SizedBox(height: 16),
            Text(
              _l10n.filesEmpty,
              style: TextStyle(
                fontSize: 18,
                color: AppTheme.colorsOf(context).textColorLight,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: _items.length + 1, // +1 for parent directory
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        // Parent directory at top
        if (index == 0) {
          return _buildParentDirectoryItem();
        }

        final item = _items[index - 1];
        final isSelected = _selectedItems.contains(item);
        final isDirectory = item is Directory;

        return ListTile(
          leading: Icon(
            isDirectory ? Icons.folder : _getFileIcon(item),
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : (isDirectory
                    ? AppTheme.colorsOf(context).warning
                    : AppTheme.colorsOf(context).info),
          ),
          title: Text(
            _getItemName(item),
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          subtitle: !isDirectory
              ? FutureBuilder<FileStat>(
                  future: item.stat(),
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      final size = snapshot.data!.size;
                      final sizeText = _formatSize(_l10n, size);
                      return Text(sizeText);
                    }
                    return const SizedBox();
                  },
                )
              : null,
          trailing: IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showItemDetails(item),
            tooltip: _l10n.filesDetails,
          ),
          selected: isSelected,
          selectedTileColor: Theme.of(context)
              .colorScheme
              .primaryContainer
              .withValues(alpha: 0.3),
          onTap: () {
            if (_isMultiSelectMode) {
              setState(() {
                if (isSelected) {
                  _selectedItems.remove(item);
                } else {
                  _selectedItems.add(item);
                }
              });
            } else if (item is Directory) {
              _navigateTo(item);
            }
          },
          onLongPress: () {
            setState(() {
              _isMultiSelectMode = true;
              if (isSelected) {
                _selectedItems.remove(item);
              } else {
                _selectedItems.add(item);
              }
            });
          },
        );
      },
    );
  }

  /// Build parent directory item
  Widget _buildParentDirectoryItem() {
    return ListTile(
      leading: Icon(
        Icons.arrow_upward,
        color: Theme.of(context).colorScheme.primary,
      ),
      title: const Text('..'),
      onTap: () {
        if (_currentDirectory.parent.path != _currentDirectory.path) {
          _navigateUp();
        }
      },
    );
  }

  /// Human-readable size with localized units (B/KB/MB, o/Ko/Mo).
  static String _formatSize(AppLocalizations l10n, int size) {
    if (size < 1024) return l10n.filesSizeBytes('$size');
    if (size < 1024 * 1024) {
      return l10n.filesSizeKb((size / 1024).toStringAsFixed(1));
    }
    return l10n.filesSizeMb((size / (1024 * 1024)).toStringAsFixed(1));
  }

  /// Get icon for file based on extension
  IconData _getFileIcon(FileSystemEntity file) {
    final extension = file.path.split('.').last.toLowerCase();

    switch (extension) {
      case 'png':
      case 'jpg':
      case 'jpeg':
      case 'gif':
      case 'bmp':
        return Icons.image;
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'txt':
      case 'md':
      case 'json':
      case 'xml':
      case 'yaml':
        return Icons.description;
      case 'zip':
      case 'tar':
      case 'gz':
      case 'rar':
      case '7z':
        return Icons.folder_zip;
      case 'mp3':
      case 'wav':
      case 'ogg':
        return Icons.audiotrack;
      case 'mp4':
      case 'avi':
      case 'mkv':
      case 'mov':
        return Icons.videocam;
      case 'dart':
      case 'js':
      case 'ts':
      case 'py':
      case 'java':
      case 'c':
      case 'cpp':
        return Icons.code;
      default:
        return Icons.insert_drive_file;
    }
  }
}
