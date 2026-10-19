import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../l10n/fuel_localizations.dart';
import '../models/fuel_calculations.dart';
import '../models/fuel_entry.dart';
import '../preferences/fuel_display_preferences.dart';

class FuelConsumptionChart extends StatefulWidget {
  const FuelConsumptionChart({
    super.key,
    required this.vehicleId,
    required this.vehicleName,
    required this.entries,
    this.consumptionUnit = FuelConsumptionUnit.kmPerLiter,
  });
  final String vehicleId;
  final String vehicleName;
  final List<FuelEntry> entries;
  final FuelConsumptionUnit consumptionUnit;
  @override
  State<FuelConsumptionChart> createState() => _FuelConsumptionChartState();
}

class _FuelConsumptionChartState extends State<FuelConsumptionChart> {
  int? _selected;
  @override
  void didUpdateWidget(covariant FuelConsumptionChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.vehicleId != widget.vehicleId ||
        oldWidget.entries != widget.entries) {
      _selected = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final id = widget.vehicleId;
    final entries = widget.entries;
    final owned = {
      for (final e in entries.where((e) => e.vehicleId == id)) e.id: e,
    };
    final all = FuelCalculations.intervals(entries, id);
    final intervals = all.skip(math.max(0, all.length - 12)).toList();
    final dates = [
      for (final interval in intervals) owned[interval.endId]!.date,
    ];
    final unit = widget.consumptionUnit;
    final alternate = unit == FuelConsumptionUnit.kmPerLiter
        ? FuelConsumptionUnit.litersPer100Km
        : FuelConsumptionUnit.kmPerLiter;
    final values = [
      for (final interval in intervals)
        unit.fromKmPerLiter(interval.kmPerLiter),
    ];
    final breaks = [
      for (var i = 0; i < intervals.length; i++)
        i == 0 || intervals[i].startId != intervals[i - 1].endId,
    ];
    final selected = values.isEmpty
        ? 0
        : (_selected ?? values.length - 1).clamp(0, values.length - 1);
    final numbers = MaterialLocalizations.of(context);
    String date(int i) => numbers.formatMediumDate(dates[i].toLocal());
    final ceiling = values.isEmpty
        ? 1.0
        : (values.reduce(math.max) * 1.2).ceilToDouble();
    final span = dates.length > 1
        ? dates.last.difference(dates.first).inMilliseconds
        : 0;
    final xs = [
      for (var i = 0; i < dates.length; i++)
        span == 0
            ? 0.5
            : dates[i].difference(dates.first).inMilliseconds / span,
    ];
    final chartHeight = math.max(
      150.0,
      MediaQuery.textScalerOf(context).scale(12) * 5,
    );
    void choose(int index) => setState(() => _selected = index);
    return Card(
      key: const Key('dashboard-fuel-chart'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.fuel('chartTitle'), style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              widget.vehicleName,
              key: const Key('fuel-chart-source'),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            if (values.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 28),
                child: Text(l.fuel('needsFull')),
              )
            else ...[
              Semantics(
                liveRegion: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${values[selected].toStringAsFixed(2)} ${l.fuel(unit.labelKey)}',
                      key: const Key('fuel-chart-value'),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${date(selected)} · ${alternate.fromKmPerLiter(intervals[selected].kmPerLiter).toStringAsFixed(2)} ${l.fuel(alternate.labelKey)}',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Directionality(
                textDirection: TextDirection.ltr,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: chartHeight,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            ceiling.toStringAsFixed(0),
                            style: theme.textTheme.labelSmall,
                          ),
                          Text(
                            (ceiling / 2).toStringAsFixed(1),
                            style: theme.textTheme.labelSmall,
                          ),
                          Text('0', style: theme.textTheme.labelSmall),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        children: [
                          LayoutBuilder(
                            builder: (context, constraints) => GestureDetector(
                              key: const Key('fuel-consumption-plot'),
                              onTapDown: (event) {
                                final fraction =
                                    (event.localPosition.dx /
                                            constraints.maxWidth)
                                        .clamp(0.0, 1.0);
                                var closest = 0;
                                for (var i = 1; i < xs.length; i++) {
                                  if ((xs[i] - fraction).abs() <
                                      (xs[closest] - fraction).abs()) {
                                    closest = i;
                                  }
                                }
                                choose(closest);
                              },
                              child: ExcludeSemantics(
                                child: CustomPaint(
                                  size: Size(constraints.maxWidth, chartHeight),
                                  painter: _FuelChartPainter(
                                    values: values,
                                    xs: xs,
                                    breaks: breaks,
                                    ceiling: ceiling,
                                    selected: selected,
                                    line: colors.primary,
                                    grid: colors.outlineVariant,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  date(0),
                                  style: theme.textTheme.labelSmall,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  date(dates.length - 1),
                                  textAlign: TextAlign.end,
                                  style: theme.textTheme.labelSmall,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  IconButton(
                    key: const Key('fuel-chart-previous'),
                    tooltip: l.fuel('previousInterval'),
                    onPressed: selected > 0 ? () => choose(selected - 1) : null,
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: Text(
                      '${l.fuel('fullIntervalsLabel')} · ${l.fuel(unit.labelKey)}',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  IconButton(
                    key: const Key('fuel-chart-next'),
                    tooltip: l.fuel('nextInterval'),
                    onPressed: selected < values.length - 1
                        ? () => choose(selected + 1)
                        : null,
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
              ExpansionTile(
                key: const Key('fuel-chart-values'),
                tilePadding: EdgeInsets.zero,
                title: Text(l.fuel('viewValues')),
                children: [
                  for (var i = 0; i < values.length; i++)
                    ListTile(
                      key: Key('fuel-chart-point-$i'),
                      selected: i == selected,
                      title: Text(date(i)),
                      subtitle: Text(
                        '${values[i].toStringAsFixed(2)} ${l.fuel(unit.labelKey)} · ${alternate.fromKmPerLiter(intervals[i].kmPerLiter).toStringAsFixed(2)} ${l.fuel(alternate.labelKey)}',
                      ),
                      onTap: () => choose(i),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FuelChartPainter extends CustomPainter {
  const _FuelChartPainter({
    required this.values,
    required this.xs,
    required this.ceiling,
    required this.selected,
    required this.line,
    required this.grid,
    required this.breaks,
  });
  final List<bool> breaks;
  final List<double> values;
  final List<double> xs;
  final double ceiling;
  final int selected;
  final Color line;
  final Color grid;
  @override
  void paint(Canvas canvas, Size size) {
    const inset = 5.0;
    final width = math.max(1.0, size.width - 2 * inset);
    final height = size.height - 2 * inset;
    final gridPaint = Paint()
      ..color = grid.withValues(alpha: 0.4)
      ..strokeWidth = 1;
    for (final fraction in [0.0, 0.5, 1.0]) {
      final y = inset + height * fraction;
      canvas.drawLine(
        Offset(inset, y),
        Offset(size.width - inset, y),
        gridPaint,
      );
    }
    if (values.isEmpty) return;
    final points = [
      for (var i = 0; i < values.length; i++)
        Offset(
          inset + xs[i] * width,
          inset + height * (1 - values[i] / ceiling),
        ),
    ];
    for (var i = 1; i < points.length; i++) {
      if (breaks[i]) continue;
      final path = Path()
        ..moveTo(points[i - 1].dx, points[i - 1].dy)
        ..lineTo(points[i].dx, points[i].dy);
      final area = Path.from(path)
        ..lineTo(points[i].dx, size.height - inset)
        ..lineTo(points[i - 1].dx, size.height - inset)
        ..close();
      canvas.drawPath(
        area,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [line.withValues(alpha: 0.2), line.withValues(alpha: 0.01)],
          ).createShader(Offset.zero & size),
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = line
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
    for (var i = 0; i < points.length; i++) {
      canvas.drawCircle(
        points[i],
        i == selected ? 5 : 3,
        Paint()..color = line,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FuelChartPainter oldDelegate) =>
      oldDelegate.selected != selected ||
      oldDelegate.ceiling != ceiling ||
      oldDelegate.line != line ||
      oldDelegate.grid != grid ||
      !listEquals(oldDelegate.values, values) ||
      !listEquals(oldDelegate.xs, xs) ||
      !listEquals(oldDelegate.breaks, breaks);
}
