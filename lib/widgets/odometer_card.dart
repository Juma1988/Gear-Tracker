import 'dart:async';

import 'package:flutter/material.dart';

import '../models/odometer_value.dart';
import '../models/valuables.dart';

class OdometerCard extends StatefulWidget {
  const OdometerCard({
    super.key,
    required this.odometer,
    required this.onChanged,
    required this.saveRevision,
    required this.isDirty,
  });

  final String odometer;
  final ValueChanged<String> onChanged;
  final int saveRevision;
  final bool isDirty;

  @override
  State<OdometerCard> createState() => _OdometerCardState();
}

class _OdometerCardState extends State<OdometerCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _saveController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );
  var _hasSaved = false;

  @override
  void didUpdateWidget(covariant OdometerCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.saveRevision != oldWidget.saveRevision) {
      _hasSaved = true;
      _saveController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _saveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reducedMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final labelColor = widget.isDirty
        ? outline
        : (_hasSaved ? primary : outline);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surfaceHigh,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: primary.withValues(alpha: .3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'LIVE Odometer Reading',
                style: TextStyle(
                  color: primary,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var index = 0; index < widget.odometer.length; index++)
                Expanded(
                  child: KeyedSubtree(
                    key: ValueKey(
                      'odometer-value-$index-${widget.odometer[index]}',
                    ),
                    child: _OdometerWheel(
                      key: Key('odometer-wheel-$index'),
                      startingDigit: int.parse(widget.odometer[index]),
                      active: index >= widget.odometer.length - 3,
                      onSettled: (delta) {
                        final nextValue = OdometerValue.adjustDigit(
                          value: widget.odometer,
                          digitIndex: index,
                          delta: delta,
                        );
                        if (nextValue != widget.odometer) {
                          widget.onChanged(nextValue);
                        }
                      },
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: AnimatedBuilder(
                  animation: _saveController,
                  builder: (context, _) {
                    final scale = reducedMotion
                        ? 1.0
                        : TweenSequence<double>([
                            TweenSequenceItem(
                              tween: Tween(begin: 1.0, end: 1.3),
                              weight: 40,
                            ),
                            TweenSequenceItem(
                              tween: Tween(begin: 1.3, end: 1.0),
                              weight: 60,
                            ),
                          ]).evaluate(_saveController);
                    final rotation = reducedMotion
                        ? 0.0
                        : TweenSequence<double>([
                            TweenSequenceItem(
                              tween: Tween(begin: 0.0, end: 0.09),
                              weight: 40,
                            ),
                            TweenSequenceItem(
                              tween: Tween(begin: 0.09, end: 0.0),
                              weight: 60,
                            ),
                          ]).evaluate(_saveController);
                    final sparkleOpacity = reducedMotion
                        ? 0.0
                        : 1 - (2 * (_saveController.value - .5)).abs();
                    return Transform.rotate(
                      angle: rotation,
                      child: Transform.scale(
                        scale: scale,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'KM',
                              style: TextStyle(
                                color: labelColor,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Opacity(
                              opacity: sparkleOpacity,
                              child: const Icon(
                                Icons.auto_awesome,
                                size: 14,
                                color: primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OdometerWheel extends StatefulWidget {
  const _OdometerWheel({
    super.key,
    required this.startingDigit,
    required this.active,
    required this.onSettled,
  });

  final int startingDigit;
  final bool active;
  final ValueChanged<int> onSettled;

  @override
  State<_OdometerWheel> createState() => _OdometerWheelState();
}

class _OdometerWheelState extends State<_OdometerWheel> {
  static const _baseItem = 50;
  late final int _initialItem = _baseItem + widget.startingDigit;
  late final FixedExtentScrollController _controller =
      FixedExtentScrollController(initialItem: _initialItem);
  Timer? _settleTimer;
  var _pendingDelta = 0;

  @override
  void dispose() {
    _settleTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onSelected(int item) {
    _pendingDelta = item - _initialItem;
    _settleTimer?.cancel();
    _settleTimer = Timer(const Duration(milliseconds: 350), () {
      widget.onSettled(_pendingDelta);
    });
  }

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(right: 3),
    width: double.infinity,
    height: 64,
    decoration: BoxDecoration(
      color: surfaceLowest,
      borderRadius: BorderRadius.circular(3),
      border: Border.all(color: const Color(0xFF3C4A42)),
    ),
    child: ListWheelScrollView.useDelegate(
      controller: _controller,
      physics: const FixedExtentScrollPhysics(),
      itemExtent: 64,
      perspective: 0.003,
      onSelectedItemChanged: _onSelected,
      childDelegate: ListWheelChildBuilderDelegate(
        childCount: 100,
        builder: (context, index) => Center(
          child: Text(
            '${index % 10}',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: widget.active ? primary : onSurface,
            ),
          ),
        ),
      ),
    ),
  );
}
