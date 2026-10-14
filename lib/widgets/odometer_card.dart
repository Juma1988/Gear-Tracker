import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../models/maintenance_health.dart';
import '../models/odometer_value.dart';
import '../theme/app_tokens.dart';
import 'service_card_content.dart';

class OdometerCard extends StatefulWidget {
  const OdometerCard({
    super.key,
    required this.odometer,
    required this.onChanged,
    required this.saveRevision,
    required this.isDirty,
    this.status = ServiceStatus.excellent,
    this.lastUpdatedAt,
    this.saveStatus = 'Saved',
    this.saveStatusKey,
  });

  final String odometer;
  final ValueChanged<String> onChanged;
  final int saveRevision;
  final bool isDirty;
  final ServiceStatus status;
  final DateTime? lastUpdatedAt;
  final String saveStatus;
  final Key? saveStatusKey;

  @override
  State<OdometerCard> createState() => _OdometerCardState();
}

class _OdometerCardState extends State<OdometerCard>
    with TickerProviderStateMixin {
  late final AnimationController _saveController = AnimationController(
    vsync: this,
    duration: AppTokens.savePulse,
  );
  late final AnimationController _breathingController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..forward();
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
    _breathingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final statusColor = serviceHealthColor(context, widget.status);
    final reducedMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final labelColor = widget.isDirty
        ? colors.outline
        : (_hasSaved ? colors.primary : colors.outline);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        border: Border.all(color: colors.primary.withValues(alpha: .3)),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: _breathingController,
                builder: (context, _) {
                  final pulse = _breathingController.value <= 0.5
                      ? _breathingController.value * 2
                      : (1 - _breathingController.value) * 2;
                  final progress = reducedMotion
                      ? 0.5
                      : 0.5 +
                          Curves.easeInOut.transform(pulse.clamp(0.0, 1.0)) *
                              0.5;
                  return Transform.scale(
                    scale: .9 + progress * .2,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                          color: statusColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: statusColor.withValues(
                              alpha: .45 + progress * .35,
                            ),
                            blurRadius: 4 + progress * 6,
                            spreadRadius: progress,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.liveOdometerReading,
                  style: AppTokens.labelStyle.copyWith(
                    color: colors.primary,
                    fontWeight: AppTokens.fontWeightBold,
                    letterSpacing: AppTokens.letterSpacingWide,
                  ),
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
                      highlighted: index >= widget.odometer.length - 3,
                      semanticPosition: switch (widget.odometer.length -
                          index) {
                        6 => l10n.hundredThousands,
                        5 => l10n.tenThousands,
                        4 => l10n.thousands,
                        3 => l10n.hundreds,
                        2 => l10n.tens,
                        1 => l10n.ones,
                        _ => null,
                      },
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
                              l10n.kilometers.toUpperCase(),
                              style: AppTokens.sectionTitleStyle.copyWith(
                                color: labelColor,
                              ),
                            ),
                            Opacity(
                              opacity: sparkleOpacity,
                              child: Icon(
                                Icons.auto_awesome,
                                size: 14,
                                color: colors.primary,
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
          const SizedBox(height: 8),
          _LastUpdatedLabel(
            lastUpdatedAt: widget.lastUpdatedAt,
            saveStatus: widget.saveStatus,
            saveStatusKey: widget.saveStatusKey,
          ),
        ],
      ),
    );
  }
}

class _LastUpdatedLabel extends StatelessWidget {
  const _LastUpdatedLabel({
    required this.lastUpdatedAt,
    required this.saveStatus,
    this.saveStatusKey,
  });

  final DateTime? lastUpdatedAt;
  final String saveStatus;
  final Key? saveStatusKey;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final label = lastUpdatedAt == null
        ? l10n.lastUpdatedUnknown
        : l10n.lastUpdatedAt(
            MaterialLocalizations.of(context)
                .formatMediumDate(lastUpdatedAt!.toLocal()),
            MaterialLocalizations.of(
              context,
            ).formatTimeOfDay(TimeOfDay.fromDateTime(lastUpdatedAt!.toLocal())),
          );
    final quietStyle = AppTokens.captionStyle.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant
          .withValues(alpha: .72),
    );
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        children: [
          Semantics(
            label: label,
            child: Text(label, softWrap: true, style: quietStyle),
          ),
          Text('•', style: quietStyle),
          Semantics(
            key: saveStatusKey,
            container: true,
            excludeSemantics: true,
            liveRegion: true,
            label: saveStatus,
            child: Text(saveStatus, style: quietStyle),
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
    required this.highlighted,
    this.semanticPosition,
    required this.onSettled,
  });

  final int startingDigit;
  final bool highlighted;
  final String? semanticPosition;
  final ValueChanged<int> onSettled;

  @override
  State<_OdometerWheel> createState() => _OdometerWheelState();
}

class _OdometerWheelState extends State<_OdometerWheel> {
  static const _baseItem = 50;
  late final int _initialItem = _baseItem + widget.startingDigit;
  late final FixedExtentScrollController _controller =
      FixedExtentScrollController(initialItem: _initialItem);
  final FocusNode _focusNode = FocusNode();
  Timer? _settleTimer;
  var _pendingDelta = 0;

  @override
  void dispose() {
    _settleTimer?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSelected(int item) {
    _pendingDelta = item - _initialItem;
    _settleTimer?.cancel();
    _settleTimer = Timer(const Duration(milliseconds: 350), () {
      widget.onSettled(_pendingDelta);
    });
  }

  void _adjustBy(int delta) {
    widget.onSettled(delta);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final wheel = Container(
      margin: const EdgeInsets.only(right: 3),
      width: double.infinity,
      height: AppTokens.odometerWheelHeight,
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppTokens.radiusChip),
        border: Border.all(color: colors.outline.withValues(alpha: .4)),
      ),
      child: ExcludeSemantics(
        child: ListWheelScrollView.useDelegate(
          controller: _controller,
          physics: const FixedExtentScrollPhysics(),
          itemExtent: AppTokens.odometerWheelHeight,
          perspective: 0.003,
          onSelectedItemChanged: _onSelected,
          childDelegate: ListWheelChildBuilderDelegate(
            childCount: 100,
            builder: (context, index) => Center(
              child: Text(
                '${index % 10}',
                style: AppTokens.displayStyle.copyWith(
                  fontFamily: 'monospace',
                  color: widget.highlighted ? colors.primary : colors.onSurface,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final place = widget.semanticPosition;
    final label = AppLocalizations.of(context)
        .digitLabel(place, '${widget.startingDigit}');
    final increasedDigit = (widget.startingDigit + 1) % 10;
    final decreasedDigit = (widget.startingDigit + 9) % 10;
    return Focus(
      focusNode: _focusNode,
      onKeyEvent: (_, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          _adjustBy(1);
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          _adjustBy(-1);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Semantics(
        label: label,
        value: '${widget.startingDigit}',
        increasedValue: '$increasedDigit',
        decreasedValue: '$decreasedDigit',
        onIncrease: () => _adjustBy(1),
        onDecrease: () => _adjustBy(-1),
        child: GestureDetector(
          onTap: () {
            _focusNode.requestFocus();
            _adjustBy(1);
          },
          child: wheel,
        ),
      ),
    );
  }
}
