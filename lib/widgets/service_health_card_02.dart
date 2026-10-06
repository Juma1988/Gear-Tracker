import 'package:flutter/material.dart';

import '../models/service_item.dart';
import '../models/tire_item.dart';

class ServiceHealthCardType02 extends StatelessWidget {
  const ServiceHealthCardType02({
    super.key,
    required this.title,
    required this.icon,
    required this.units,
    required this.currentOdometer,
    required this.onEditUnit,
  }) : assert(units.length == 4);

  final String title;
  final IconData icon;
  final List<TireItem> units;
  final int currentOdometer;
  final ValueChanged<TireItem> onEditUnit;

  static const _surfaceLow = Color(0xFF131B2E);
  static const _muted = Color(0xFFBBCABF);
  static const _primary = Color(0xFF4EDEA3);
  static const _warning = Color(0xFFFFB95F);
  static const _error = Color(0xFFFFB4AB);

  static Color colorFor(ServiceStatus status) => switch (status) {
    ServiceStatus.replaceNow => _error,
    ServiceStatus.warning || ServiceStatus.replaceSoon => _warning,
    ServiceStatus.good || ServiceStatus.excellent => _primary,
  };

  @override
  Widget build(BuildContext context) {
    final worst = units
        .map((unit) => unit.metricsAt(currentOdometer).status)
        .reduce((a, b) => b.index > a.index ? b : a);
    final color = colorFor(worst);
    return Container(
      height: 125,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _surfaceLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: .45)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              _StatusPill(label: worst.badge.toUpperCase(), color: color),
            ],
          ),
          _UnitRow(
            left: units[0],
            right: units[1],
            currentOdometer: currentOdometer,
            onEditUnit: onEditUnit,
          ),
          _UnitRow(
            left: units[2],
            right: units[3],
            currentOdometer: currentOdometer,
            onEditUnit: onEditUnit,
          ),
        ],
      ),
    );
  }
}

class _UnitRow extends StatelessWidget {
  const _UnitRow({
    required this.left,
    required this.right,
    required this.currentOdometer,
    required this.onEditUnit,
  });

  final TireItem left;
  final TireItem right;
  final int currentOdometer;
  final ValueChanged<TireItem> onEditUnit;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: _ServiceUnit(
          unit: left,
          currentOdometer: currentOdometer,
          onDoubleTap: () => onEditUnit(left),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: _ServiceUnit(
          unit: right,
          currentOdometer: currentOdometer,
          codeAtEnd: true,
          onDoubleTap: () => onEditUnit(right),
        ),
      ),
    ],
  );
}

class _ServiceUnit extends StatelessWidget {
  const _ServiceUnit({
    required this.unit,
    required this.currentOdometer,
    required this.onDoubleTap,
    this.codeAtEnd = false,
  });

  final TireItem unit;
  final int currentOdometer;
  final VoidCallback onDoubleTap;
  final bool codeAtEnd;

  @override
  Widget build(BuildContext context) {
    final metrics = unit.metricsAt(currentOdometer);
    final color = ServiceHealthCardType02.colorFor(metrics.status);
    final chip = _UnitCode(unit.code);
    return GestureDetector(
      onDoubleTap: onDoubleTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (!codeAtEnd) ...[chip, const SizedBox(width: 6)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  metrics.showCondition
                      ? metrics.condition.toUpperCase()
                      : '${metrics.damagePercent}% USED · ${metrics.usedKm} KM',
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  textAlign: TextAlign.left,
                  style: TextStyle(
                    color: metrics.showCondition
                        ? color
                        : ServiceHealthCardType02._muted,
                    fontSize: 8,
                    fontWeight: metrics.showCondition
                        ? FontWeight.bold
                        : FontWeight.w600,
                    letterSpacing: metrics.showCondition ? .3 : 0,
                  ),
                ),
                const SizedBox(height: 4),
                _UnitProgressBar(value: metrics.health, color: color),
              ],
            ),
          ),
          if (codeAtEnd) ...[const SizedBox(width: 6), chip],
        ],
      ),
    );
  }
}

class _UnitProgressBar extends StatelessWidget {
  const _UnitProgressBar({required this.value, required this.color});

  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(10),
    child: LinearProgressIndicator(
      value: value,
      minHeight: 6,
      color: color,
      backgroundColor: const Color(0xFF060E20),
    ),
  );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(3),
      border: Border.all(color: color.withValues(alpha: .35)),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: color,
        fontSize: 10,
        fontWeight: FontWeight.bold,
        letterSpacing: .5,
      ),
    ),
  );
}

class _UnitCode extends StatelessWidget {
  const _UnitCode(this.code);

  final String code;

  @override
  Widget build(BuildContext context) => Container(
    width: 28,
    height: 20,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: ServiceHealthCardType02._primary.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      code,
      style: const TextStyle(
        color: ServiceHealthCardType02._primary,
        fontSize: 10,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}
