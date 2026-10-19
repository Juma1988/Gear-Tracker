import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/service_item.dart';
import '../theme/app_tokens.dart';

/// Presentation helpers shared by the health-card widgets.
///
/// These live beside the content widgets so both the service card and the
/// tire grid can map a [ServiceStatus] to one consistent accent colour, key,
/// and icon instead of repeating the same switch statements.
Color serviceHealthColor(BuildContext context, ServiceStatus status) =>
    switch (status) {
      ServiceStatus.replaceNow => Theme.of(context).colorScheme.error,
      ServiceStatus.warning ||
      ServiceStatus.replaceSoon => Theme.of(context).colorScheme.tertiary,
      ServiceStatus.good ||
      ServiceStatus.excellent => Theme.of(context).colorScheme.primary,
    };

ServiceStatusKey serviceHealthStatusKey(ServiceStatus status) =>
    switch (status) {
      ServiceStatus.excellent => ServiceStatusKey.excellent,
      ServiceStatus.good => ServiceStatusKey.good,
      ServiceStatus.warning => ServiceStatusKey.warning,
      ServiceStatus.replaceSoon => ServiceStatusKey.replaceSoon,
      ServiceStatus.replaceNow => ServiceStatusKey.replaceNow,
    };

IconData serviceHealthStatusIcon(ServiceStatus status) => switch (status) {
  ServiceStatus.replaceNow => Icons.error_outline,
  ServiceStatus.warning ||
  ServiceStatus.replaceSoon => Icons.warning_amber_outlined,
  ServiceStatus.good || ServiceStatus.excellent => Icons.check_circle_outline,
};

/// Presentation-ready values for a single service health card.
///
/// Keeping the decision logic out of the widget tree makes the card's
/// conditional layout (condition line, details toggle, detail copy, progress)
/// directly testable without pumping a widget.
class ServiceCardViewData {
  const ServiceCardViewData({
    required this.metrics,
    required this.overallStatus,
    required this.statusLabel,
    required this.statusIcon,
    required this.color,
    required this.remainingKmLabel,
    required this.detail,
    required this.timeProgress,
    required this.showsConditionLine,
    required this.showsDetailsToggle,
    required this.alwaysShowsDetail,
  });

  factory ServiceCardViewData.of(
    BuildContext context, {
    required ServiceItem service,
    required int currentOdometer,
    DateTime? now,
  }) {
    final l10n = AppLocalizations.of(context);
    final numbers = MaterialLocalizations.of(context);
    final metrics = service.metricsAt(currentOdometer);
    final overallStatus = service.statusAt(currentOdometer, now: now);
    final shelfLife = service.shelfLifeStatusAt(now ?? DateTime.now());
    final statusLabel = l10n.status(serviceHealthStatusKey(overallStatus));
    final showsConditionLine = metrics?.showCondition == true;
    final timeProgress = service.tracksTime
        ? _timeProgress(service, now ?? DateTime.now())
        : null;
    final detail = showsConditionLine
        ? l10n.condition(
            serviceHealthStatusKey(metrics!.status),
            numbers.formatDecimal(metrics.damagePercent),
          )
        : shelfLife == null
        ? (service.note.isEmpty
              ? statusLabel
              : l10n.serviceCardNote(id: service.id, fallback: service.note))
        : shelfLife.isDueOrExpired
        ? l10n.checkOverdueBy(numbers.formatDecimal(-shelfLife.daysRemaining))
        : l10n.checkIn(numbers.formatDecimal(shelfLife.daysRemaining));

    return ServiceCardViewData(
      metrics: metrics,
      overallStatus: overallStatus,
      statusLabel: statusLabel,
      statusIcon: serviceHealthStatusIcon(overallStatus),
      color: serviceHealthColor(context, overallStatus),
      remainingKmLabel: metrics == null
          ? null
          : numbers.formatDecimal(metrics.remainingKm),
      detail: detail,
      timeProgress: timeProgress,
      showsConditionLine: showsConditionLine,
      showsDetailsToggle: false,
      alwaysShowsDetail: metrics == null,
    );
  }

  final ServiceMetrics? metrics;
  final ServiceStatus overallStatus;
  final String statusLabel;
  final IconData statusIcon;
  final Color color;
  final String? remainingKmLabel;
  final String detail;
  final double? timeProgress;
  final bool showsConditionLine;
  final bool showsDetailsToggle;
  final bool alwaysShowsDetail;

  /// The detail copy is shown when the user expanded the details, or when the
  /// card has no mileage metric at all (a time-based service).
  bool showsDetailText(bool showDetails) =>
      (showDetails || alwaysShowsDetail) &&
      !showsConditionLine &&
      timeProgress == null;
}

double _timeProgress(ServiceItem service, DateTime now) {
  final start = service.installDate!;
  final startDay = DateTime(start.year, start.month, start.day);
  final due = service.shelfLifeDueDate!;
  final dueDay = DateTime(due.year, due.month, due.day);
  final today = DateTime(now.year, now.month, now.day);
  final totalDays = dueDay.difference(startDay).inDays;
  if (totalDays <= 0) return 0;
  return (dueDay.difference(today).inDays / totalDays).clamp(0.0, 1.0);
}

/// A labelled progress bar used by the service card and the tire tiles.
class HealthProgressBar extends StatelessWidget {
  const HealthProgressBar({
    super.key,
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.color,
    required this.backgroundColor,
    required this.height,
  });

  final String label;
  final String valueLabel;
  final double value;
  final Color color;
  final Color backgroundColor;
  final double height;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    value: valueLabel,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(AppTokens.radiusInput),
      child: LinearProgressIndicator(
        value: value,
        minHeight: height,
        color: color,
        backgroundColor: backgroundColor,
      ),
    ),
  );
}

/// A quiet visual cue for services tracked by time rather than mileage.
class TimeBasedIndicator extends StatelessWidget {
  const TimeBasedIndicator({super.key, required this.progress, this.size = 20});

  final double progress;
  final double size;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final color = progress < .1
        ? colors.error
        : progress < .25
        ? colors.tertiary
        : colors.onSurfaceVariant.withValues(alpha: .45);
    return Semantics(
      label: l10n.timeBased,
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Icon(
          Icons.schedule_outlined,
          size: size,
          color: color.withValues(alpha: .45),
        ),
      ),
    );
  }
}

/// The tinted service icon badge shown at the start of a service card.
class ServiceIconBadge extends StatelessWidget {
  const ServiceIconBadge({super.key, required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: AppTokens.serviceIconBadgeSize,
    height: AppTokens.serviceIconBadgeSize,
    decoration: BoxDecoration(
      color: color.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(AppTokens.radiusSm),
      border: Border.all(color: color.withValues(alpha: .3)),
    ),
    child: Icon(icon, color: color, size: AppTokens.serviceIconGlyphSize),
  );
}

/// The status chip used by the service health card.
class ServiceStatusPill extends StatelessWidget {
  const ServiceStatusPill({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsetsDirectional.fromSTEB(6, 2, 6, 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(AppTokens.radiusPill),
      border: Border.all(color: color.withValues(alpha: .35)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: AppTokens.pillIconSize, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: AppTokens.captionStyle.copyWith(
            color: color,
            fontWeight: AppTokens.fontWeightBold,
          ),
        ),
      ],
    ),
  );
}

/// The icon, service name, and optional condition line.
class ServiceCardHeader extends StatelessWidget {
  const ServiceCardHeader({
    super.key,
    required this.service,
    required this.data,
  });

  final ServiceItem service;
  final ServiceCardViewData data;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final numbers = MaterialLocalizations.of(context);
    final metrics = data.metrics;
    return Row(
      crossAxisAlignment: data.metrics == null
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        ServiceIconBadge(icon: service.icon, color: data.color),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: l10n.serviceCardName(
                              id: service.id,
                              iconKey: service.iconKey,
                              fallback: service.name,
                            ),
                            style: AppTokens.cardTitleStyle,
                          ),
                          TextSpan(
                            text: ' //',
                            style: AppTokens.cardTitleStyle.copyWith(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                          ),
                          TextSpan(
                            text: data.statusLabel.toUpperCase(),
                            style: AppTokens.cardTitleStyle.copyWith(
                              color: data.color,
                              fontWeight: AppTokens.fontWeightBold,
                            ),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.fade,
                      softWrap: false,
                    ),
                  ),
                  if (data.timeProgress case final progress?)
                    ExcludeSemantics(
                      child: TimeBasedIndicator(progress: progress),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Wrap(
                spacing: 8,
                runSpacing: 2,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (metrics != null)
                    Text(
                      l10n.remaining(
                        percent: numbers.formatDecimal(
                          metrics.remainingPercent,
                        ),
                        distance: data.remainingKmLabel!,
                      ),
                      style: AppTokens.labelStyle.copyWith(
                        color: data.color,
                        fontWeight: AppTokens.fontWeightBold,
                      ),
                    ),
                  if (data.showsConditionLine)
                    Text(
                      data.detail,
                      style: AppTokens.labelStyle.copyWith(
                        color: data.color,
                        fontWeight: AppTokens.fontWeightSemiBold,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The status pill, details toggle, detail copy, and remaining-distance row.
class ServiceCardStatusWrap extends StatelessWidget {
  const ServiceCardStatusWrap({
    super.key,
    required this.service,
    required this.data,
    required this.showDetails,
    required this.onToggleDetails,
  });

  final ServiceItem service;
  final ServiceCardViewData data;
  final bool showDetails;
  final VoidCallback onToggleDetails;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (data.showsDetailText(showDetails))
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              data.detail,
              style: AppTokens.labelStyle.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}

/// The progress bar and used/interval distance captions for a mileage service.
class ServiceCardProgressSection extends StatelessWidget {
  const ServiceCardProgressSection({super.key, required this.data});

  final ServiceCardViewData data;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final numbers = MaterialLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final metrics = data.metrics!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HealthProgressBar(
          label: l10n.progressLabel(
            numbers.formatDecimal(metrics.remainingPercent),
          ),
          valueLabel: '${metrics.remainingPercent}%',
          value: metrics.health,
          color: data.color,
          backgroundColor: colors.surfaceContainerLowest,
          height: AppTokens.progressBarHeight,
        ),
        const SizedBox(height: 3),
        Wrap(
          spacing: 12,
          runSpacing: 4,
          alignment: WrapAlignment.spaceBetween,
          children: [
            Text(
              l10n.usedDistance(numbers.formatDecimal(metrics.usedKm)),
              style: AppTokens.captionStyle.copyWith(color: colors.outline),
            ),
            Text(
              l10n.intervalDistance(numbers.formatDecimal(metrics.intervalKm)),
              style: AppTokens.captionStyle.copyWith(color: colors.outline),
            ),
          ],
        ),
      ],
    );
  }
}

/// The tappable body of a service card.
class ServiceCardContent extends StatelessWidget {
  const ServiceCardContent({
    super.key,
    required this.service,
    required this.data,
    required this.showDetails,
    required this.onToggleDetails,
  });

  final ServiceItem service;
  final ServiceCardViewData data;
  final bool showDetails;
  final VoidCallback onToggleDetails;

  @override
  Widget build(BuildContext context) => Padding(
    key: const Key('service-health-card-content'),
    padding: const EdgeInsetsDirectional.fromSTEB(10, 8, 10, 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ServiceCardHeader(service: service, data: data),
        if (data.showsDetailText(showDetails)) ...[
          const SizedBox(height: 3),
          ServiceCardStatusWrap(
            service: service,
            data: data,
            showDetails: showDetails,
            onToggleDetails: onToggleDetails,
          ),
        ],
        if (data.metrics != null) const SizedBox(height: 3),
        if (data.metrics != null) ServiceCardProgressSection(data: data),
      ],
    ),
  );
}
