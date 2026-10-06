import 'package:flutter/material.dart';

import '../models/service_item.dart';

class ServiceHealthCardType01 extends StatelessWidget {
  const ServiceHealthCardType01({
    super.key,
    required this.service,
    required this.currentOdometer,
    required this.onDoubleTap,
  });

  final ServiceItem service;
  final int currentOdometer;
  final VoidCallback onDoubleTap;

  static const _surfaceLow = Color(0xFF131B2E);
  static const _surfaceLowest = Color(0xFF060E20);
  static const _muted = Color(0xFFBBCABF);
  static const _outline = Color(0xFF86948A);
  static const _primary = Color(0xFF4EDEA3);
  static const _warning = Color(0xFFFFB95F);
  static const _error = Color(0xFFFFB4AB);

  Color _color(ServiceStatus status) => switch (status) {
    ServiceStatus.replaceNow => _error,
    ServiceStatus.warning || ServiceStatus.replaceSoon => _warning,
    ServiceStatus.good || ServiceStatus.excellent => _primary,
  };

  @override
  Widget build(BuildContext context) {
    final metrics = service.metricsAt(currentOdometer);
    final color = _color(metrics.status);
    final detail = metrics.showCondition
        ? metrics.condition.toUpperCase()
        : service.note;
    return GestureDetector(
      onDoubleTap: onDoubleTap,
      child: Container(
        height: 125,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: color.withValues(alpha: .3)),
                  ),
                  child: Icon(service.icon, color: color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        service.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        detail,
                        style: TextStyle(
                          color: metrics.showCondition ? color : _muted,
                          fontSize: 10,
                          fontWeight: metrics.showCondition
                              ? FontWeight.bold
                              : FontWeight.w600,
                          letterSpacing: metrics.showCondition ? .4 : 0,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _StatusPill(label: metrics.badge.toUpperCase(), color: color),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Remaining Lifespan',
                  style: TextStyle(color: _muted, fontSize: 11),
                ),
                Text(
                  '${metrics.remainingPercent}% · ${metrics.remainingKm} KM Left',
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: metrics.health,
                minHeight: 8,
                color: color,
                backgroundColor: _surfaceLowest,
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Used: ${metrics.usedKm} KM',
                  style: const TextStyle(color: _outline, fontSize: 10),
                ),
                Text(
                  'Interval: ${metrics.intervalKm} KM',
                  style: const TextStyle(color: _outline, fontSize: 10),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
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
