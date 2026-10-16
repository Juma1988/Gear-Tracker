import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/service_item.dart';
import '../models/tire_item.dart';
import '../theme/app_tokens.dart';
import 'card_action_menu.dart';
import 'service_card_content.dart';

/// The content arrangement displayed by [ServiceHealthCard].
enum ServiceHealthCardLayout { service, tireGrid }

/// A configurable health-card preview for one service or a four-tire set.
///
/// The named constructors make the data and callback required by each layout
/// explicit, preventing a service card from being configured with tire data
/// (and vice versa).
class ServiceHealthCard extends StatefulWidget {
  const ServiceHealthCard.service({
    super.key,
    required this.service,
    required this.currentOdometer,
    required this.onEditService,
    this.onDeleteService,
    this.now,
  }) : layout = ServiceHealthCardLayout.service,
       tires = null,
       onEditTire = null,
       compact = false,
       hideAtNarrowLargeText = false;

  factory ServiceHealthCard.tireGrid({
    Key? key,
    required List<TireItem> tires,
    required int currentOdometer,
    required ValueChanged<TireItem> onEditTire,
    bool compact = false,
    bool hideAtNarrowLargeText = false,
  }) {
    assert(_isValidTireSet(tires));
    return ServiceHealthCard._tireGrid(
      key: key,
      tires: List.unmodifiable(tires),
      currentOdometer: currentOdometer,
      onEditTire: onEditTire,
      compact: compact,
      hideAtNarrowLargeText: hideAtNarrowLargeText,
    );
  }

  const ServiceHealthCard._tireGrid({
    super.key,
    required this.tires,
    required this.currentOdometer,
    required this.onEditTire,
    required this.compact,
    required this.hideAtNarrowLargeText,
  }) : layout = ServiceHealthCardLayout.tireGrid,
       service = null,
       onEditService = null,
       onDeleteService = null,
       now = null;

  final ServiceHealthCardLayout layout;
  final ServiceItem? service;
  final List<TireItem>? tires;
  final int currentOdometer;
  final VoidCallback? onEditService;
  final VoidCallback? onDeleteService;
  final ValueChanged<TireItem>? onEditTire;
  final bool compact;
  final bool hideAtNarrowLargeText;
  final DateTime? now;

  @override
  State<ServiceHealthCard> createState() => _ServiceHealthCardState();
}

bool _isValidTireSet(List<TireItem> tires) =>
    tires.length == TireItem.positionIds.length &&
    tires.map((tire) => tire.id).toSet().containsAll(TireItem.positionIds);

double _tireTimeProgress(TireItem tire, DateTime now) {
  final due = tire.shelfLifeDueDate;
  if (due == null) return 0;
  final start = DateTime(
    tire.installDate.year,
    tire.installDate.month,
    tire.installDate.day,
  );
  final dueDay = DateTime(due.year, due.month, due.day);
  final today = DateTime(now.year, now.month, now.day);
  final totalDays = dueDay.difference(start).inDays;
  if (totalDays <= 0) return 0;
  return (dueDay.difference(today).inDays / totalDays).clamp(0.0, 1.0);
}

class _ServiceHealthCardState extends State<ServiceHealthCard> {
  @override
  Widget build(BuildContext context) => switch (widget.layout) {
    ServiceHealthCardLayout.service => _ServiceCard(
      key: Key('service-health-card-content-${widget.service!.id}'),
      service: widget.service!,
      currentOdometer: widget.currentOdometer,
      onTap: widget.onEditService!,
      onDelete: widget.onDeleteService,
      now: widget.now,
    ),
    ServiceHealthCardLayout.tireGrid => _TireGridCard(
      key: const Key('service-health-card-tire-grid'),
      tires: widget.tires!,
      currentOdometer: widget.currentOdometer,
      onEditTire: widget.onEditTire!,
      compact: widget.compact,
      hideAtNarrowLargeText: widget.hideAtNarrowLargeText,
    ),
  };
}

class _ServiceCard extends StatefulWidget {
  const _ServiceCard({
    super.key,
    required this.service,
    required this.currentOdometer,
    required this.onTap,
    this.onDelete,
    this.now,
  });

  final ServiceItem service;
  final int currentOdometer;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  final DateTime? now;

  @override
  State<_ServiceCard> createState() => _ServiceCardState();
}

class _ServiceCardState extends State<_ServiceCard> {
  bool _hasFocus = false;
  bool _showDetails = false;

  Future<void> _showServiceActions(BuildContext context) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(AppLocalizations.of(sheetContext).editServiceHint),
              onTap: () => Navigator.pop(sheetContext, 'edit'),
            ),
            ListTile(
              leading: Icon(
                Icons.delete_outline,
                color: Theme.of(sheetContext).colorScheme.error,
              ),
              title: Text(AppLocalizations.of(sheetContext).deleteService),
              onTap: () => Navigator.pop(sheetContext, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'edit') widget.onTap();
    if (action == 'delete') widget.onDelete?.call();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final numbers = MaterialLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final data = ServiceCardViewData.of(
      context,
      service: widget.service,
      currentOdometer: widget.currentOdometer,
      now: widget.now,
    );
    final metrics = data.metrics;
    final color = data.color;
    final status = data.statusLabel;
    final remainingKm = data.remainingKmLabel;
    final displayName = l10n.serviceCardName(
      id: widget.service.id,
      iconKey: widget.service.iconKey,
      fallback: widget.service.name,
    );

    final tapContent = FocusableActionDetector(
      onShowFocusHighlight: (hasFocus) => setState(() => _hasFocus = hasFocus),
      child: ServiceCardContent(
        service: widget.service,
        data: data,
        showDetails: _showDetails,
        onToggleDetails: () => setState(() => _showDetails = !_showDetails),
      ),
    );
    return Semantics(
      key: Key('service-health-card-${widget.service.id}'),
      button: true,
      container: true,
      explicitChildNodes: true,
      label: l10n.serviceSummary(
        name: displayName,
        status: status,
        remainingPercent: numbers.formatDecimal(metrics?.remainingPercent ?? 0),
        remainingKm: remainingKm ?? l10n.timeBased,
      ),
      hint: l10n.editServiceHint,
      onTap: widget.onTap,
      onLongPress: () => _showServiceActions(context),
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            color: colors.surfaceContainer,
            borderRadius: BorderRadius.circular(AppTokens.radiusSm),
            border: Border.all(
              color: _hasFocus ? color : color.withValues(alpha: .45),
              width: _hasFocus ? 2 : 1,
            ),
          ),
          child: InkWell(
            onTap: widget.onTap,
            onLongPress: () => _showServiceActions(context),
            borderRadius: BorderRadius.circular(AppTokens.radiusSm),
            focusColor: color.withValues(alpha: .18),
            hoverColor: color.withValues(alpha: .08),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: ExcludeSemantics(child: tapContent)),
                if (widget.onDelete != null)
                  CardActionMenu(
                    key: Key('service-health-card-menu-${widget.service.id}'),
                    tooltip: l10n.serviceMenuTooltip,
                    actions: [
                      CardActionMenuAction(
                        value: 'edit',
                        icon: Icons.edit_outlined,
                        label: l10n.editServiceHint,
                        onSelected: widget.onTap,
                      ),
                      CardActionMenuAction(
                        value: 'delete',
                        icon: Icons.delete_outline,
                        label: l10n.deleteService,
                        isDestructive: true,
                        onSelected: widget.onDelete!,
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TireGridCard extends StatelessWidget {
  const _TireGridCard({
    super.key,
    required this.tires,
    required this.currentOdometer,
    required this.onEditTire,
    required this.compact,
    required this.hideAtNarrowLargeText,
  });

  final List<TireItem> tires;
  final int currentOdometer;
  final ValueChanged<TireItem> onEditTire;
  final bool compact;
  final bool hideAtNarrowLargeText;

  @override
  Widget build(BuildContext context) {
    if (hideAtNarrowLargeText &&
        MediaQuery.sizeOf(context).width <= 400 &&
        MediaQuery.textScalerOf(context).scale(1) > 1.5) {
      return const SizedBox.shrink();
    }
    final byPosition = {for (final tire in tires) tire.id: tire};
    final orderedTires = [
      for (final id in TireItem.positionIds) byPosition[id]!,
    ];
    final worst = orderedTires
        .map((tire) => tire.metricsAt(currentOdometer).status)
        .reduce((a, b) => b.index > a.index ? b : a);
    final color = serviceHealthColor(context, worst);
    final colors = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    final textScale = MediaQuery.textScalerOf(context).scale(1);
    return SizedBox(
      height: (AppTokens.healthCardHeight + (textScale - 1) * 42)
          .clamp(AppTokens.healthCardHeight, double.infinity)
          .toDouble(),
      child: Container(
        padding: const EdgeInsetsDirectional.all(10),
        decoration: BoxDecoration(
          color: colors.surfaceContainer,
          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
          border: Border.all(color: color.withValues(alpha: .45)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.tire_repair, color: color, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(l10n.tireHealth, style: AppTokens.cardTitleStyle),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        _tire(context, orderedTires[0]),
                        const SizedBox(width: 6),
                        _tire(context, orderedTires[1]),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: Row(
                      children: [
                        _tire(context, orderedTires[2]),
                        const SizedBox(width: 6),
                        _tire(context, orderedTires[3]),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tire(BuildContext context, TireItem tire) => Expanded(
    child: _TireTile(
      tire: tire,
      currentOdometer: currentOdometer,
      compact: compact,
      onTap: () => _handleTireTap(context, tire),
    ),
  );

  void _handleTireTap(BuildContext context, TireItem tire) {
    if (!compact) {
      onEditTire(tire);
      return;
    }
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Expanded(child: Text(l10n.checkTirePrompt)),
            TextButton(
              onPressed: () =>
                  ScaffoldMessenger.of(context).hideCurrentSnackBar(),
              child: Text(l10n.ignore),
            ),
          ],
        ),
        action: SnackBarAction(
          label: l10n.checkTire,
          onPressed: () => onEditTire(tire),
        ),
      ),
    );
  }
}

class _TireTile extends StatelessWidget {
  const _TireTile({
    required this.tire,
    required this.currentOdometer,
    required this.compact,
    required this.onTap,
  });

  final TireItem tire;
  final int currentOdometer;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final metrics = tire.metricsAt(currentOdometer);
    final colors = Theme.of(context).colorScheme;
    final color = compact && metrics.remainingPercent <= 10
        ? colors.error
        : serviceHealthColor(context, metrics.status);
    final l10n = AppLocalizations.of(context);
    final numbers = MaterialLocalizations.of(context);
    final status = l10n.status(serviceHealthStatusKey(metrics.status));
    final remainingPercent = numbers.formatDecimal(metrics.remainingPercent);
    final remainingKm = numbers.formatDecimal(metrics.remainingKm);
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.5;

    return Semantics(
      button: true,
      label: l10n.tireSummary(
        position: l10n.tirePosition(tire.id),
        status: status,
        remainingPercent: remainingPercent,
        remainingKm: remainingKm,
      ),
      hint: l10n.editTireHint,
      onTap: onTap,
      child: ExcludeSemantics(
        child: Material(
          color: Colors.transparent,
          child: Ink(
            decoration: BoxDecoration(
              color: colors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(AppTokens.radiusSm),
              border: Border.all(color: color.withValues(alpha: .3)),
            ),
            child: InkWell(
              key: Key('tire-tile-${tire.id}'),
              onTap: onTap,
              borderRadius: BorderRadius.circular(AppTokens.radiusSm),
              focusColor: color.withValues(alpha: .18),
              hoverColor: color.withValues(alpha: .08),
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(6, 3, 6, 6),
                child: Column(
                  mainAxisAlignment: compact
                      ? MainAxisAlignment.center
                      : MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Text(
                          '${tire.code} //',
                          style: AppTokens.captionStyle.copyWith(
                            color: color,
                            fontWeight: AppTokens.fontWeightBold,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            status.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTokens.captionStyle.copyWith(
                              color: color,
                              fontWeight: AppTokens.fontWeightBold,
                            ),
                          ),
                        ),
                        const Spacer(),
                        if (tire.shelfLifeDueDate != null)
                          TimeBasedIndicator(
                            progress: _tireTimeProgress(tire, DateTime.now()),
                            size: 14,
                          ),
                      ],
                    ),
                    if (!compact &&
                        !largeText &&
                        MediaQuery.sizeOf(context).width > 400) ...[
                      const SizedBox(height: 4),
                      HealthProgressBar(
                        label: l10n.tireProgressLabel(remainingPercent),
                        valueLabel: l10n.tireRemaining(
                          percent: remainingPercent,
                          distance: remainingKm,
                        ),
                        value: metrics.health,
                        color: color,
                        backgroundColor: colors.surfaceContainerHigh,
                        height: AppTokens.progressBarThinHeight,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
