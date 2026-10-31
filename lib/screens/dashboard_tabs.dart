import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/server_models.dart';
import '../services/telemetry_service.dart';
import '../theme/app_colors.dart';
import '../utils/formatters.dart';
import '../widgets/charts.dart';
import '../widgets/glass.dart';
import '../widgets/skeleton.dart';

// =============================================================================
// Shared layout helpers
// =============================================================================

/// Scrollable tab body: centred max-width column with bottom inset so content
/// never hides behind the floating glass nav bar.
class TabScroll extends StatelessWidget {
  final List<Widget> children;
  const TabScroll({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = math.max(16.0, (constraints.maxWidth - 1100) / 2);
        return ListView.separated(
          padding: EdgeInsets.fromLTRB(side, 8, side, 120),
          itemCount: children.length,
          separatorBuilder: (_, _) => const SizedBox(height: 16),
          itemBuilder: (_, i) => children[i],
        );
      },
    );
  }
}

/// Lays children out in 1..[maxColumns] equal-width columns.
class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final double minItemWidth;
  final int maxColumns;
  final double spacing;

  const ResponsiveGrid({
    super.key,
    required this.children,
    this.minItemWidth = 440,
    this.maxColumns = 2,
    this.spacing = 16,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = (constraints.maxWidth / minItemWidth).floor().clamp(1, maxColumns);
        final rows = <Widget>[];
        for (var i = 0; i < children.length; i += cols) {
          if (rows.isNotEmpty) rows.add(SizedBox(height: spacing));
          rows.add(
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var j = 0; j < cols; j++) ...[
                  if (j > 0) SizedBox(width: spacing),
                  Expanded(
                    child: i + j < children.length ? children[i + j] : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          );
        }
        return Column(children: rows);
      },
    );
  }
}

/// Large header card with a gauge and key/value facts.
class _HeroCard extends StatelessWidget {
  final String title;
  final double percent;
  final String gaugeLabel;
  final Color accent;
  final List<(String, String)> facts;

  const _HeroCard({
    required this.title,
    required this.percent,
    required this.gaugeLabel,
    required this.accent,
    required this.facts,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      glowColor: accent,
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          GlassGauge(percent: percent, color: accent, label: gaugeLabel, size: 92),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: SysDashColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                for (final (k, v) in facts)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            k,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: SysDashColors.textSecondary, fontSize: 12),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            v,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: SysDashColors.textPrimary,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 1. OVERVIEW
// =============================================================================
class OverviewTab extends StatelessWidget {
  final TelemetryService service;
  final int selectedIndex;
  final ValueChanged<int> onSelectNode;
  final ValueChanged<int> onOpenTab;

  const OverviewTab({
    super.key,
    required this.service,
    required this.selectedIndex,
    required this.onSelectNode,
    required this.onOpenTab,
  });

  @override
  Widget build(BuildContext context) {
    final s = LanguageScope.of(context);
    final nodes = service.nodes;
    final node = nodes[selectedIndex];

    return TabScroll(
      children: [
        ResponsiveGrid(
          minItemWidth: 160,
          maxColumns: 4,
          spacing: 12,
          children: [
            _SummaryTile(icon: Icons.verified_user_rounded, label: s.uptime, value: node.uptimeLabel, accent: SysDashColors.statusEmerald),
            _SummaryTile(icon: Icons.hub_rounded, label: s.nodesOnline, value: '${nodes.length} / ${nodes.length}', accent: SysDashColors.cpuCyan),
            _SummaryTile(icon: Icons.bolt_rounded, label: s.sshLatency, value: '${node.sshPingMs} ms', accent: SysDashColors.diskAmber),
            _SummaryTile(icon: Icons.view_in_ar_rounded, label: s.containers, value: '${node.runningContainers} / ${node.containers.length}', accent: SysDashColors.ramViolet),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader(
              title: s.fleet,
              badge: '${nodes.length} ${s.nodes}',
              accent: SysDashColors.statusEmerald,
            ),
            for (var i = 0; i < nodes.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: _NodeCard(
                  node: nodes[i],
                  selected: i == selectedIndex,
                  onTap: () => onSelectNode(i),
                ),
              ),
            ],
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader(title: s.resources, badge: node.name, accent: SysDashColors.cpuCyan),
            ResponsiveGrid(
              minItemWidth: 160,
              maxColumns: 4,
              spacing: 12,
              children: [
                _ResourceTile(
                  icon: Icons.memory_rounded,
                  title: 'CPU',
                  value: formatMetric(node.value(MetricKey.cpu), '%'),
                  subtitle: '${node.cpuCores} ${s.cores}',
                  color: SysDashColors.cpuCyan,
                  samples: node.live[MetricKey.cpu]!,
                  onTap: () => onOpenTab(1),
                ),
                _ResourceTile(
                  icon: Icons.developer_board_rounded,
                  title: s.tabMemory,
                  value: formatMetric(node.value(MetricKey.memory), '%'),
                  subtitle: node.ramUsedFormatted.isNotEmpty && node.ramTotalFormatted.isNotEmpty
                      ? '${node.ramUsedFormatted} / ${node.ramTotalFormatted}'
                      : '${formatGb(node.ramUsedGb > 0 ? node.ramUsedGb : (node.ramTotalGb * node.value(MetricKey.memory) / 100))} / ${formatGb(node.ramTotalGb)}',
                  color: SysDashColors.ramViolet,
                  samples: node.live[MetricKey.memory]!,
                  onTap: () => onOpenTab(2),
                ),
                _ResourceTile(
                  icon: Icons.storage_rounded,
                  title: s.tabDisks,
                  value: formatMetric(node.diskTotalGb > 0 ? (node.diskUsedGb / node.diskTotalGb * 100) : 0, '%'),
                  subtitle: (node.mounts.length == 1 && node.mounts.first.usedFormatted.isNotEmpty && node.mounts.first.totalFormatted.isNotEmpty)
                      ? '${node.mounts.first.usedFormatted} / ${node.mounts.first.totalFormatted}'
                      : '${formatGb(node.diskUsedGb)} / ${formatGb(node.diskTotalGb)}',
                  color: SysDashColors.diskAmber,
                  samples: node.live[MetricKey.diskRead]!,
                  sparkMax: 400,
                  onTap: () => onOpenTab(3),
                ),
                _ResourceTile(
                  icon: Icons.swap_vert_rounded,
                  title: s.tabNetwork,
                  value: formatMetric(node.value(MetricKey.netRx), 'Mbps', compact: true),
                  subtitle: '↑ ${formatMetric(node.value(MetricKey.netTx), 'Mbps', compact: true)}',
                  color: SysDashColors.netIndigo,
                  samples: node.live[MetricKey.netRx]!,
                  sparkMax: 600,
                  onTap: () => onOpenTab(4),
                ),
              ],
            ),
          ],
        ),
        MetricChartCard(
          service: service,
          node: node,
          title: 'CPU & RAM',
          icon: Icons.insights_rounded,
          accent: SysDashColors.cpuCyan,
          unit: '%',
          fixedMax: 100,
          lines: [
            const MetricLine(MetricKey.cpu, 'CPU', SysDashColors.cpuCyan),
            MetricLine(MetricKey.memory, 'RAM', SysDashColors.ramViolet),
          ],
        ),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  const _SummaryTile({required this.icon, required this.label, required this.value, required this.accent});

  @override
  Widget build(BuildContext context) => GlassCard(
    glowColor: accent,
    borderRadius: 16,
    padding: const EdgeInsets.all(12),
    child: Row(
      children: [
        IconBadge(icon: icon, color: accent, size: 34),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: SysDashColors.textSecondary, fontSize: 11)),
              const SizedBox(height: 2),
              Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: SysDashColors.textPrimary, fontSize: 14.5, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ResourceTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String subtitle;
  final Color color;
  final List<TimedSample> samples;
  final double sparkMax;
  final VoidCallback onTap;

  const _ResourceTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
    required this.samples,
    required this.onTap,
    this.sparkMax = 100,
  });

  @override
  Widget build(BuildContext context) => GlassCard(
    glowColor: color,
    borderRadius: 18,
    padding: const EdgeInsets.all(14),
    onTap: onTap,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconBadge(icon: icon, color: color, size: 32),
            const Spacer(),
            Flexible(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(title, style: const TextStyle(color: SysDashColors.textPrimary, fontSize: 13.5, fontWeight: FontWeight.w700)),
        Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: SysDashColors.textSecondary, fontSize: 11.5)),
        const SizedBox(height: 10),
        SizedBox(height: 38, width: double.infinity, child: Sparkline(samples: samples, color: color, max: sparkMax)),
      ],
    ),
  );
}

class _NodeCard extends StatelessWidget {
  final ServerNode node;
  final bool selected;
  final VoidCallback onTap;

  const _NodeCard({required this.node, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final diskPct = node.diskUsedGb / node.diskTotalGb * 100;
    return GlassCard(
      onTap: onTap,
      highlighted: selected,
      glowColor: selected ? SysDashColors.cpuCyan : SysDashColors.statusEmerald,
      borderRadius: 18,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: SysDashColors.statusEmerald,
                  boxShadow: [
                    BoxShadow(
                      color: SysDashColors.statusEmerald.withValues(alpha: 0.8),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  node.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: SysDashColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GlassPill(
                text: '↑ ${node.uptime.inDays}d',
                color: SysDashColors.statusEmerald,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                node.sshAddress,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: SysDashColors.cpuCyan,
                  fontSize: 12,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                node.osKernel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: SysDashColors.textSecondary,
                  fontSize: 11.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${node.cpuModel} • ${node.physicalCores}C/${node.logicalCores}T @ ${node.formattedSpeed}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: SysDashColors.textMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MiniBar(
                  label: 'CPU',
                  percent: node.value(MetricKey.cpu),
                  color: SysDashColors.cpuCyan,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MiniBar(
                  label: 'RAM',
                  percent: node.value(MetricKey.memory),
                  color: SysDashColors.ramViolet,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MiniBar(
                  label: 'DISK',
                  percent: diskPct,
                  color: SysDashColors.diskAmber,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniBar extends StatelessWidget {
  final String label;
  final double percent;
  final Color color;
  const _MiniBar({required this.label, required this.percent, required this.color});

  @override
  Widget build(BuildContext context) {
    final validPct = percent.isNaN || percent.isInfinite ? 0.0 : percent.clamp(0.0, 100.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: SysDashColors.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '${validPct >= 10 ? validPct.round() : validPct.toStringAsFixed(1)}%',
              style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 4),
        GlassProgressBar(value: validPct / 100, color: color, height: 5),
      ],
    );
  }
}

// =============================================================================
// 2. CPU
// =============================================================================
class CpuTab extends StatelessWidget {
  final TelemetryService service;
  final ServerNode node;
  const CpuTab({super.key, required this.service, required this.node});

  @override
  Widget build(BuildContext context) {
    final s = LanguageScope.of(context);
    final cpu = node.value(MetricKey.cpu);
    return TabScroll(
      children: [
        _HeroCard(
          title: node.cpuModel,
          percent: cpu,
          gaugeLabel: formatMetric(cpu, '%'),
          accent: SysDashColors.cpuCyan,
          facts: [
            (s.physicalCores, '${node.physicalCores} ${s.cores}'),
            (s.logicalCores, '${node.logicalCores} ${s.threads}'),
            (s.cpuSpeed, node.formattedSpeed),
            (s.cpuTemp, formatMetric(node.value(MetricKey.cpuTemp), '°C')),
            (s.loadAverage, node.loadAverage),
          ],
        ),
        ResponsiveGrid(
          minItemWidth: 160,
          maxColumns: 3,
          spacing: 12,
          children: [
            _SummaryTile(
              icon: Icons.developer_board_rounded,
              label: s.physicalCores,
              value: '${node.physicalCores} ${s.cores}',
              accent: SysDashColors.cpuCyan,
            ),
            _SummaryTile(
              icon: Icons.alt_route_rounded,
              label: s.logicalCores,
              value: '${node.logicalCores} ${s.threads}',
              accent: SysDashColors.ramViolet,
            ),
            _SummaryTile(
              icon: Icons.speed_rounded,
              label: s.cpuSpeed,
              value: node.formattedSpeed,
              accent: SysDashColors.statusEmerald,
            ),
          ],
        ),
        ResponsiveGrid(
          children: [
            MetricChartCard(
              service: service,
              node: node,
              title: s.cpuUsage,
              icon: Icons.memory_rounded,
              accent: SysDashColors.cpuCyan,
              unit: '%',
              fixedMax: 100,
              lines: const [MetricLine(MetricKey.cpu, 'CPU', SysDashColors.cpuCyan)],
            ),
            MetricChartCard(
              service: service,
              node: node,
              title: s.cpuTemp,
              icon: Icons.thermostat_rounded,
              accent: SysDashColors.tempOrange,
              unit: '°C',
              fixedMax: 100,
              lines: [MetricLine(MetricKey.cpuTemp, s.cpuTemp, SysDashColors.tempOrange)],
            ),
          ],
        ),
        GlassCard(
          glowColor: SysDashColors.cpuCyan,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionHeader(
                title: s.perCore,
                badge: '${node.physicalCores} ${s.cores} • ${node.logicalCores} ${s.threads}',
              ),
              if (node.coreLoads.isNotEmpty)
                ResponsiveGrid(
                  minItemWidth: 140,
                  maxColumns: 4,
                  spacing: 12,
                  children: [
                    for (var i = 0; i < node.coreLoads.length; i++)
                      _MiniBar(
                        label: 'Core $i',
                        percent: node.coreLoads[i],
                        color: SysDashColors.forUsage(node.coreLoads[i]) == SysDashColors.statusEmerald
                            ? SysDashColors.cpuCyan
                            : SysDashColors.forUsage(node.coreLoads[i]),
                      ),
                  ],
                )
              else
                SkeletonCoreLoadsGrid(
                  cores: node.logicalCores > 0 ? node.logicalCores : 4,
                  accent: SysDashColors.cpuCyan,
                ),
            ],
          ),
        ),
        if (node.topProcesses.isNotEmpty)
          Builder(
            builder: (context) {
              final displayed = node.topProcesses.take(service.processLimit).toList();
              return GlassCard(
                glowColor: SysDashColors.cpuCyan,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SectionHeader(
                      title: s.topProcesses,
                      badge: '${displayed.length} proc',
                      accent: SysDashColors.cpuCyan,
                      trailing: _ProcessLimitSelector(
                        selected: service.processLimit,
                        accent: SysDashColors.cpuCyan,
                        onSelected: service.setProcessLimit,
                      ),
                    ),
                    for (var i = 0; i < displayed.length; i++) ...[
                      if (i > 0)
                        Divider(height: 18, color: Colors.white.withValues(alpha: 0.08)),
                      _ProcessRow(proc: displayed[i]),
                    ],
                  ],
                ),
              );
            },
          )
        else
          SkeletonProcessList(
            title: s.topProcesses,
            count: service.processLimit,
            accent: SysDashColors.cpuCyan,
          ),
      ],
    );
  }
}

class _ProcessRow extends StatelessWidget {
  final SystemProcessItem proc;
  final bool highlightMemory;
  const _ProcessRow({required this.proc, this.highlightMemory = false});

  @override
  Widget build(BuildContext context) {
    final badgeColor = highlightMemory ? SysDashColors.ramViolet : SysDashColors.cpuCyan;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            '${proc.pid}',
            style: const TextStyle(
              color: SysDashColors.textSecondary,
              fontFamily: 'monospace',
              fontSize: 10.5,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                proc.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: SysDashColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                highlightMemory
                    ? 'CPU: ${proc.cpuPercent.toStringAsFixed(1)}%'
                    : 'RAM: ${formatMb(proc.memoryRss / (1024 * 1024))} (${proc.memoryPercent.toStringAsFixed(1)}%)',
                style: const TextStyle(
                  color: SysDashColors.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: badgeColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            highlightMemory
                ? 'RAM ${formatMb(proc.memoryRss / (1024 * 1024))} (${proc.memoryPercent.toStringAsFixed(1)}%)'
                : 'CPU ${proc.cpuPercent.toStringAsFixed(1)}%',
            style: TextStyle(
              color: badgeColor,
              fontFamily: 'monospace',
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _ProcessLimitSelector extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onSelected;
  final Color accent;

  const _ProcessLimitSelector({
    required this.selected,
    required this.onSelected,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: SysDashColors.glassBorderSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [5, 10, 15, 20].map((limit) {
          final isSel = selected == limit;
          return Semantics(
            button: true,
            selected: isSel,
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: () => onSelected(limit),
                borderRadius: BorderRadius.circular(8),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isSel ? accent.withValues(alpha: 0.25) : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSel ? accent.withValues(alpha: 0.8) : Colors.transparent,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    '$limit',
                    style: TextStyle(
                      color: isSel ? SysDashColors.textPrimary : SysDashColors.textMuted,
                      fontSize: 11,
                      fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// =============================================================================
// 3. MEMORY
// =============================================================================
class MemoryTab extends StatelessWidget {
  final TelemetryService service;
  final ServerNode node;
  const MemoryTab({super.key, required this.service, required this.node});

  @override
  Widget build(BuildContext context) {
    final s = LanguageScope.of(context);
    final used = node.value(MetricKey.memory);
    final swap = node.value(MetricKey.swap);
    final usedRamGb = node.ramUsedGb > 0 ? node.ramUsedGb : (node.ramTotalGb * used / 100);
    final freeRamGb = math.max(0.0, node.ramTotalGb - usedRamGb);
    final usedSwapGb = node.swapUsedGb > 0 ? node.swapUsedGb : (node.swapTotalGb * swap / 100);

    final hasRealBreakdown = node.ramBuffCacheGb != null;
    final buffCachePct = hasRealBreakdown
        ? (node.ramTotalGb > 0 ? (node.ramBuffCacheGb! / node.ramTotalGb * 100).clamp(0.0, 100.0) : 0.0)
        : 0.0;
    final freePct = hasRealBreakdown
        ? (node.ramFreeGb != null && node.ramTotalGb > 0
            ? (node.ramFreeGb! / node.ramTotalGb * 100).clamp(0.0, 100.0)
            : math.max(0.0, 100.0 - used - buffCachePct))
        : math.max(0.0, 100.0 - used - 19.5);
    final cachedFallback = math.min(16.0, math.max(0.0, 100 - used - 3.5 - 4));
    final freeFallback = math.max(0.0, 100 - used - 3.5 - cachedFallback);

    final segments = hasRealBreakdown
        ? [
            (s.used, used, SysDashColors.ramViolet),
            (s.buffCache, buffCachePct, SysDashColors.cpuCyan),
            (s.free, freePct, SysDashColors.textMuted),
          ]
        : [
            (s.used, used, SysDashColors.ramViolet),
            (s.cached, cachedFallback, SysDashColors.cpuCyan),
            (s.buffers, 3.5, SysDashColors.diskAmber),
            (s.free, freeFallback, SysDashColors.textMuted),
          ];

    final ramTitle = node.ramTotalFormatted.isNotEmpty
        ? 'RAM ${node.ramTotalFormatted}'
        : 'RAM ${formatGb(node.ramTotalGb)}';
    final ramUsedText = node.ramUsedFormatted.isNotEmpty
        ? node.ramUsedFormatted
        : formatGb(usedRamGb);
    final ramAvailText = node.ramAvailableGb != null
        ? formatGb(node.ramAvailableGb!)
        : formatGb(freeRamGb);

    return TabScroll(
      children: [
        _HeroCard(
          title: ramTitle,
          percent: used,
          gaugeLabel: formatMetric(used, '%'),
          accent: SysDashColors.ramViolet,
          facts: [
            (s.used, ramUsedText),
            (s.available, ramAvailText),
            if (node.ramBuffCacheGb != null)
              (s.buffCache, formatGb(node.ramBuffCacheGb!)),
            ('Swap', '${formatGb(usedSwapGb)} / ${formatGb(node.swapTotalGb)}'),
          ],
        ),
        GlassCard(
          glowColor: SysDashColors.ramViolet,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionHeader(title: s.memBreakdown, accent: SysDashColors.ramViolet),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  height: 16,
                  child: Row(
                    children: [
                      for (final (_, pct, color) in segments)
                        Expanded(
                          flex: math.max(1, (pct * 10).round()),
                          child: Container(color: color.withValues(alpha: 0.85)),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 16,
                runSpacing: 10,
                children: [
                  for (final (label, pct, color) in segments)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
                        const SizedBox(width: 6),
                        Text('$label  ', style: const TextStyle(color: SysDashColors.textSecondary, fontSize: 12)),
                        Text(formatGb(node.ramTotalGb * pct / 100), style: const TextStyle(color: SysDashColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w700)),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
        ResponsiveGrid(
          children: [
            MetricChartCard(
              service: service,
              node: node,
              title: s.ramUsage,
              icon: Icons.developer_board_rounded,
              accent: SysDashColors.ramViolet,
              unit: '%',
              fixedMax: 100,
              lines: const [MetricLine(MetricKey.memory, 'RAM', SysDashColors.ramViolet)],
            ),
            MetricChartCard(
              service: service,
              node: node,
              title: s.swapUsage,
              icon: Icons.sync_alt_rounded,
              accent: SysDashColors.swapPink,
              unit: '%',
              fixedMax: 100,
              lines: const [MetricLine(MetricKey.swap, 'Swap', SysDashColors.swapPink)],
            ),
          ],
        ),
        if (node.topMemoryProcesses.isNotEmpty)
          Builder(
            builder: (context) {
              final displayed = node.topMemoryProcesses.take(service.processLimit).toList();
              return GlassCard(
                glowColor: SysDashColors.ramViolet,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SectionHeader(
                      title: s.topMemoryProcesses,
                      badge: '${displayed.length} proc',
                      accent: SysDashColors.ramViolet,
                      trailing: _ProcessLimitSelector(
                        selected: service.processLimit,
                        accent: SysDashColors.ramViolet,
                        onSelected: service.setProcessLimit,
                      ),
                    ),
                    for (var i = 0; i < displayed.length; i++) ...[
                      if (i > 0)
                        Divider(height: 18, color: Colors.white.withValues(alpha: 0.08)),
                      _ProcessRow(
                        proc: displayed[i],
                        highlightMemory: true,
                      ),
                    ],
                  ],
                ),
              );
            },
          )
        else
          SkeletonProcessList(
            title: s.topMemoryProcesses,
            count: service.processLimit,
            accent: SysDashColors.ramViolet,
          ),
      ],
    );
  }
}

// =============================================================================
// 4. DISKS
// =============================================================================
class DisksTab extends StatelessWidget {
  final TelemetryService service;
  final ServerNode node;
  const DisksTab({super.key, required this.service, required this.node});

  @override
  Widget build(BuildContext context) {
    final s = LanguageScope.of(context);
    final pct = node.diskUsedGb / node.diskTotalGb * 100;
    return TabScroll(
      children: [
        _HeroCard(
          title: '${s.diskUsage} • ${node.mounts.length} ${s.mountPoints.toLowerCase()}',
          percent: pct,
          gaugeLabel: formatMetric(pct, '%'),
          accent: SysDashColors.diskAmber,
          facts: [
            (s.used, formatGb(node.diskUsedGb)),
            (s.free, formatGb(node.diskTotalGb - node.diskUsedGb)),
            ('${s.read} / ${s.write}', '${formatMetric(node.value(MetricKey.diskRead), 'MB/s', compact: true)} / ${formatMetric(node.value(MetricKey.diskWrite), 'MB/s', compact: true)}'),
          ],
        ),
        if (node.mounts.isNotEmpty)
          GlassCard(
            glowColor: SysDashColors.diskAmber,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionHeader(title: s.mountPoints, badge: formatGb(node.diskTotalGb), accent: SysDashColors.diskAmber),
                for (var i = 0; i < node.mounts.length; i++) ...[
                  if (i > 0) Divider(height: 24, color: Colors.white.withValues(alpha: 0.08)),
                  _MountRow(mount: node.mounts[i]),
                ],
              ],
            ),
          )
        else
          const SkeletonDiskList(count: 3, accent: SysDashColors.diskAmber),
        ResponsiveGrid(
          children: [
            MetricChartCard(
              service: service,
              node: node,
              title: s.diskUsage,
              icon: Icons.storage_rounded,
              accent: SysDashColors.diskAmber,
              unit: '%',
              fixedMax: 100,
              lines: [MetricLine(MetricKey.disk, s.used, SysDashColors.diskAmber)],
            ),
            MetricChartCard(
              service: service,
              node: node,
              title: s.diskIo,
              icon: Icons.speed_rounded,
              accent: SysDashColors.diskAmber,
              unit: 'MB/s',
              lines: [
                MetricLine(MetricKey.diskRead, s.read, SysDashColors.diskAmber),
                MetricLine(MetricKey.diskWrite, s.write, SysDashColors.diskWriteRose),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _MountRow extends StatelessWidget {
  final DiskMount mount;
  const _MountRow({required this.mount});

  @override
  Widget build(BuildContext context) {
    final color = SysDashColors.forUsage(mount.percent);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.folder_open_rounded, size: 18, color: SysDashColors.diskAmber),
            const SizedBox(width: 8),
            Expanded(
              child: Text(mount.mountPoint, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: SysDashColors.textPrimary, fontWeight: FontWeight.w700, fontFamily: 'monospace', fontSize: 13)),
            ),
            Text('${mount.percent.toStringAsFixed(1)}%', style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 13)),
          ],
        ),
        const SizedBox(height: 8),
        GlassProgressBar(value: mount.percent / 100, color: color, height: 7),
        const SizedBox(height: 6),
        Text(
          mount.usedFormatted.isNotEmpty && mount.totalFormatted.isNotEmpty
              ? '${mount.device} • ${mount.fileSystem} • ${mount.usedFormatted} / ${mount.totalFormatted}'
              : '${mount.device} • ${mount.fileSystem} • ${formatGb(mount.usedGb)} / ${formatGb(mount.totalGb)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: SysDashColors.textSecondary, fontSize: 11.5),
        ),
      ],
    );
  }
}

// =============================================================================
// 5. NETWORK
// =============================================================================
class NetworkTab extends StatelessWidget {
  final TelemetryService service;
  final ServerNode node;
  const NetworkTab({super.key, required this.service, required this.node});

  @override
  Widget build(BuildContext context) {
    final s = LanguageScope.of(context);
    return TabScroll(
      children: [
        Row(
          children: [
            Expanded(
              child: _ThroughputTile(
                icon: Icons.south_rounded,
                label: s.download,
                value: formatMetric(node.value(MetricKey.netRx), 'Mbps'),
                color: SysDashColors.netIndigo,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ThroughputTile(
                icon: Icons.north_rounded,
                label: s.upload,
                value: formatMetric(node.value(MetricKey.netTx), 'Mbps'),
                color: SysDashColors.netTxTeal,
              ),
            ),
          ],
        ),
        MetricChartCard(
          service: service,
          node: node,
          title: s.bandwidth,
          icon: Icons.swap_vert_rounded,
          accent: SysDashColors.netIndigo,
          unit: 'Mbps',
          chartHeight: 200,
          lines: [
            MetricLine(MetricKey.netRx, s.download, SysDashColors.netIndigo),
            MetricLine(MetricKey.netTx, s.upload, SysDashColors.netTxTeal),
          ],
        ),
        if (node.interfaces.isNotEmpty)
          GlassCard(
            glowColor: SysDashColors.netIndigo,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionHeader(title: s.interfaces, badge: '${node.interfaces.length}', accent: SysDashColors.netIndigo),
                for (var i = 0; i < node.interfaces.length; i++) ...[
                  if (i > 0) Divider(height: 24, color: Colors.white.withValues(alpha: 0.08)),
                  _InterfaceRow(nic: node.interfaces[i], strings: s),
                ],
              ],
            ),
          )
        else
          const SkeletonNetworkList(count: 2, accent: SysDashColors.netIndigo),
      ],
    );
  }
}

class _ThroughputTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _ThroughputTile({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => GlassCard(
    glowColor: color,
    borderRadius: 18,
    padding: const EdgeInsets.all(14),
    child: Row(
      children: [
        IconBadge(icon: icon, color: color, size: 36),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: SysDashColors.textSecondary, fontSize: 11.5)),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _InterfaceRow extends StatelessWidget {
  final NetInterface nic;
  final AppStrings strings;
  const _InterfaceRow({required this.nic, required this.strings});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const IconBadge(icon: Icons.settings_ethernet_rounded, color: SysDashColors.netIndigo, size: 36),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(nic.name, style: const TextStyle(color: SysDashColors.textPrimary, fontWeight: FontWeight.w700, fontFamily: 'monospace')),
            Text('${nic.ipv4} • ${nic.mac}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: SysDashColors.textSecondary, fontSize: 11.5)),
          ],
        ),
      ),
      Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text('↓ ${formatGb(nic.rxTotalGb)}', style: const TextStyle(color: SysDashColors.netIndigo, fontSize: 12, fontWeight: FontWeight.w700)),
          Text('↑ ${formatGb(nic.txTotalGb)}', style: const TextStyle(color: SysDashColors.netTxTeal, fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    ],
  );
}

// =============================================================================
// 6. CONTAINERS
// =============================================================================
class ContainersTab extends StatelessWidget {
  final TelemetryService service;
  final ServerNode node;
  const ContainersTab({super.key, required this.service, required this.node});

  @override
  Widget build(BuildContext context) {
    final s = LanguageScope.of(context);

    if (!service.isDockerLoaded) {
      return TabScroll(
        children: [
          ContainersSkeletonTab(strings: s),
        ],
      );
    }

    final running = node.containers.where((c) => c.isRunning);
    final totalCpu = running.fold<double>(0, (a, c) => a + c.cpuPercent);
    final totalMem = running.fold<double>(0, (a, c) => a + c.memMb);

    return TabScroll(
      children: [
        ResponsiveGrid(
          minItemWidth: 150,
          maxColumns: 4,
          spacing: 12,
          children: [
            _SummaryTile(icon: Icons.play_circle_outline_rounded, label: s.running, value: '${node.runningContainers} / ${node.containers.length}', accent: SysDashColors.statusEmerald),
            _SummaryTile(icon: Icons.album_outlined, label: s.dockerImages, value: '${node.dockerImages.length}', accent: SysDashColors.diskAmber),
            _SummaryTile(icon: Icons.memory_rounded, label: 'CPU', value: formatMetric(totalCpu, '%'), accent: SysDashColors.cpuCyan),
            _SummaryTile(icon: Icons.developer_board_rounded, label: 'RAM', value: formatMb(totalMem), accent: SysDashColors.ramViolet),
          ],
        ),
        ResponsiveGrid(
          children: [
            MetricChartCard(
              service: service,
              node: node,
              title: s.containersCpu,
              icon: Icons.view_in_ar_rounded,
              accent: SysDashColors.cpuCyan,
              unit: '%',
              fixedMax: 100,
              lines: const [MetricLine(MetricKey.dockerCpu, 'CPU', SysDashColors.cpuCyan)],
            ),
            MetricChartCard(
              service: service,
              node: node,
              title: s.containersMem,
              icon: Icons.layers_rounded,
              accent: SysDashColors.ramViolet,
              unit: '%',
              fixedMax: 100,
              lines: const [MetricLine(MetricKey.dockerMem, 'RAM', SysDashColors.ramViolet)],
            ),
          ],
        ),
        GlassCard(
          glowColor: SysDashColors.netIndigo,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionHeader(title: s.containerList, badge: '${node.containers.length}', accent: SysDashColors.netIndigo),
              if (node.containers.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text(s.noContainers, style: const TextStyle(color: SysDashColors.textSecondary, fontSize: 13)),
                  ),
                )
              else
                for (var i = 0; i < node.containers.length; i++) ...[
                  if (i > 0) Divider(height: 24, color: Colors.white.withValues(alpha: 0.08)),
                  _ContainerRow(c: node.containers[i], strings: s),
                ],
            ],
          ),
        ),
        GlassCard(
          glowColor: SysDashColors.diskAmber,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionHeader(
                title: s.dockerImages,
                badge: '${node.dockerImages.length}',
                accent: SysDashColors.diskAmber,
              ),
              if (node.dockerImages.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text(s.noImages, style: const TextStyle(color: SysDashColors.textSecondary, fontSize: 13)),
                  ),
                )
              else
                for (var i = 0; i < node.dockerImages.length; i++) ...[
                  if (i > 0) Divider(height: 24, color: Colors.white.withValues(alpha: 0.08)),
                  _DockerImageRow(image: node.dockerImages[i]),
                ],
            ],
          ),
        ),
      ],
    );
  }
}

class _DockerImageRow extends StatelessWidget {
  final DockerImageItem image;
  const _DockerImageRow({required this.image});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const IconBadge(icon: Icons.layers_rounded, color: SysDashColors.diskAmber, size: 36),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                image.primaryTag,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: SysDashColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 13.5),
              ),
              const SizedBox(height: 2),
              Text(
                [
                  'ID: ${image.id}',
                  '${image.containersCount} containers${image.runningContainersCount > 0 ? ' (${image.runningContainersCount} running)' : ''}',
                  if (image.memUsageBytes > 0) 'RAM ${image.formattedMem}',
                ].join(' • '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: SysDashColors.textSecondary, fontSize: 11),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        GlassPill(text: image.formattedSize, color: SysDashColors.diskAmber),
      ],
    );
  }
}

class _ContainerRow extends StatelessWidget {
  final ContainerInfo c;
  final AppStrings strings;
  const _ContainerRow({required this.c, required this.strings});

  @override
  Widget build(BuildContext context) {
    final status = c.isRunning ? SysDashColors.statusEmerald : SysDashColors.textSecondary;
    final effectiveMemPct = c.memPercent > 0
        ? c.memPercent
        : (c.memLimitMb > 0 ? (c.memMb / c.memLimitMb * 100).clamp(0.0, 100.0) : 0.0);
    final ramLabel = c.memUsageFormatted.isNotEmpty
        ? 'RAM ${c.memUsageFormatted}'
        : (c.memMb > 0 ? 'RAM ${formatMb(c.memMb)}' : 'RAM 0 MB');
    final cpuLabel = c.cpuPercent > 0
        ? 'CPU ${c.cpuPercent.toStringAsFixed(2)}%'
        : 'CPU 0%';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const IconBadge(icon: Icons.view_in_ar_rounded, color: SysDashColors.netIndigo, size: 36),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: SysDashColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 13.5)),
                  Text('${c.image}:${c.tag}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: SysDashColors.cpuCyan, fontFamily: 'monospace', fontSize: 11.5)),
                ],
              ),
            ),
            GlassPill(text: c.isRunning ? strings.running : strings.stopped, color: status),
          ],
        ),
        if (c.isRunning) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _MiniBar(label: cpuLabel, percent: c.cpuPercent, color: SysDashColors.cpuCyan)),
              const SizedBox(width: 12),
              Expanded(child: _MiniBar(label: ramLabel, percent: effectiveMemPct, color: SysDashColors.ramViolet)),
            ],
          ),
        ],
        const SizedBox(height: 6),
        Text(
          [
            if (c.imageId.isNotEmpty) c.imageId,
            if (c.ports.isNotEmpty && c.ports != '—') 'ports ${c.ports}',
            if (c.uptime.isNotEmpty) '↑ ${c.uptime}',
          ].join(' • '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: SysDashColors.textSecondary, fontSize: 11),
        ),
      ],
    );
  }
}
