import 'package:flutter/material.dart';

class RefreshableScreen extends StatefulWidget {
  final Widget child;
  final Future<void> Function()? onRefresh;
  final String? errorMessage;

  const RefreshableScreen({
    required this.child,
    this.onRefresh,
    this.errorMessage,
    super.key,
  });

  @override
  State<RefreshableScreen> createState() => _RefreshableScreenState();
}

class _RefreshableScreenState extends State<RefreshableScreen> {
  bool _isRefreshing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _error = widget.errorMessage;
  }

  @override
  void didUpdateWidget(RefreshableScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.errorMessage != oldWidget.errorMessage) {
      setState(() => _error = widget.errorMessage);
    }
  }

  Future<void> _handleRefresh() async {
    if (_isRefreshing) return;
    setState(() {
      _isRefreshing = true;
      _error = null;
    });

    try {
      await widget.onRefresh?.call();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isRefreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final errorColor = theme.colorScheme.error;

    final childWithError = _error != null
        ? Column(
            children: [
              // The child is usually scrollable (ListView, TabBarView); it
              // needs a bounded height inside the Column or layout throws and
              // the error banner never shows.
              Expanded(child: widget.child),
              if (_error != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  color: errorColor.withValues(alpha: 0.1),
                  child: Row(
                    children: [
                      Icon(Icons.error, color: errorColor, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(_error!,
                              style: TextStyle(color: errorColor))),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => setState(() => _error = null),
                      ),
                    ],
                  ),
                ),
            ],
          )
        : widget.child;

    final content = Stack(
      children: [
        childWithError,
        if (_isRefreshing)
          Positioned(
            top: 8,
            right: 8,
            child: CircularProgressIndicator(
              color: theme.colorScheme.primary,
            ),
          ),
      ],
    );

    if (widget.onRefresh != null) {
      return RefreshIndicator(
        onRefresh: _handleRefresh,
        color: theme.colorScheme.primary,
        child: content,
      );
    }

    return content;
  }
}
