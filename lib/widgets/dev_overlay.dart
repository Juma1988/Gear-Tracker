import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart';

class DevOverlay extends StatefulWidget {
  const DevOverlay({super.key, required this.child});

  final Widget child;
  static String currentFilePath = 'unknown';

  @override
  State<DevOverlay> createState() => _DevOverlayState();
}

class _DevOverlayState extends State<DevOverlay> {
  Timer? _tapTimer;
  int _tapCount = 0;
  bool _actionsVisible = false;

  @override
  void dispose() {
    _tapTimer?.cancel();
    super.dispose();
  }

  void _toggleOnTripleTap() {
    _tapCount++;
    _tapTimer?.cancel();
    _tapTimer = Timer(const Duration(milliseconds: 500), () => _tapCount = 0);
    if (_tapCount >= 3) {
      _tapCount = 0;
      _tapTimer?.cancel();
      setState(() => _actionsVisible = !_actionsVisible);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!isDebug) return widget.child;
    return Stack(
      children: [
        widget.child,
        Positioned(
          top: MediaQuery.paddingOf(context).top + 4,
          left: 8,
          child: GestureDetector(
            onTap: _toggleOnTripleTap,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_actionsVisible) ...[
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Long-press to restart',
                    onLongPress: () => RestartWidget.restartApp(context),
                    onPressed: () {},
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy),
                    tooltip: 'Copy current file path',
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: DevOverlay.currentFilePath),
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(DevOverlay.currentFilePath)),
                        );
                      }
                    },
                  ),
                ] else
                  const Opacity(opacity: 0.08, child: Icon(Icons.code)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
