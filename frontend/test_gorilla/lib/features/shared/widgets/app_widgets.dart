import 'package:flutter/material.dart';
import 'package:test_gorilla/core/theme/app_theme.dart';

class ResponsiveLayout extends StatelessWidget {
  final Widget mobileWidget;
  final Widget? tabletWidget;
  final Widget? desktopWidget;
  final int mobileBreakpoint;
  final int tabletBreakpoint;

  const ResponsiveLayout({
    Key? key,
    required this.mobileWidget,
    this.tabletWidget,
    this.desktopWidget,
    this.mobileBreakpoint = 600,
    this.tabletBreakpoint = 1024,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < mobileBreakpoint) {
          return mobileWidget;
        } else if (constraints.maxWidth < tabletBreakpoint) {
          return tabletWidget ?? mobileWidget;
        } else {
          return desktopWidget ?? (tabletWidget ?? mobileWidget);
        }
      },
    );
  }
}

class LoadingWidget extends StatelessWidget {
  final String? message;

  const LoadingWidget({Key? key, this.message}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
              if (message != null) ...[
                const SizedBox(width: 12),
                Text(message!, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class ErrorWidget extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const ErrorWidget({Key? key, required this.message, this.onRetry})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppTheme.errorColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.error_outline,
                size: 34,
                color: AppTheme.errorColor,
              ),
            ),
            const SizedBox(height: 16),
            Text('Error', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: scheme.primary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class EmptyStateWidget extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback? onAction;
  final String? actionLabel;

  const EmptyStateWidget({
    Key? key,
    required this.title,
    this.subtitle,
    this.icon = Icons.inbox_outlined,
    this.onAction,
    this.actionLabel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final mutedText = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]);

    return Center(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 56, color: Colors.grey[400]),
              const SizedBox(height: 14),
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              if (subtitle != null) ...[
                const SizedBox(height: 8),
                Text(subtitle!, textAlign: TextAlign.center, style: mutedText),
              ],
              if (onAction != null && actionLabel != null) ...[
                const SizedBox(height: 20),
                ElevatedButton(onPressed: onAction, child: Text(actionLabel!)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class AppPageScaffold extends StatelessWidget {
  final Widget child;
  final double maxContentWidth;
  final EdgeInsetsGeometry? padding;

  const AppPageScaffold({
    Key? key,
    required this.child,
    this.maxContentWidth = 980,
    this.padding,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 700;

        return SingleChildScrollView(
          padding:
              padding ??
              EdgeInsets.symmetric(
                horizontal: isMobile ? 16 : 24,
                vertical: isMobile ? 16 : 24,
              ),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxContentWidth),
              child: child,
            ),
          ),
        );
      },
    );
  }
}

class GlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const GlassPanel({
    Key? key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFFFFF), Color(0xFFFAFCFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class StatusBadge extends StatelessWidget {
  final String label;
  final String status;

  const StatusBadge({Key? key, required this.label, required this.status})
    : super(key: key);

  Color _statusColor() {
    switch (status.toLowerCase()) {
      case 'published':
      case 'passed':
      case 'success':
        return AppTheme.successColor;
      case 'draft':
      case 'pending':
        return AppTheme.warningColor;
      case 'archived':
      case 'failed':
      case 'error':
        return AppTheme.errorColor;
      default:
        return const Color(0xFF64748B);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class TestCard extends StatelessWidget {
  final String title;
  final String? description;
  final int duration;
  final int questions;
  final String status;
  final Color? highlightColor;
  final VoidCallback onTap;
  final String? actionLabel;
  final bool actionEnabled;
  final IconData? actionIcon;
  final VoidCallback? onAction;
  final String? destructiveActionLabel;
  final VoidCallback? onDestructiveAction;

  const TestCard({
    Key? key,
    required this.title,
    this.description,
    required this.duration,
    required this.questions,
    required this.status,
    this.highlightColor,
    required this.onTap,
    this.actionLabel,
    this.actionEnabled = true,
    this.actionIcon,
    this.onAction,
    this.destructiveActionLabel,
    this.onDestructiveAction,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: const Color(0xFF64748B));
    final baseCardColor = Theme.of(context).cardColor;
    final cardColor = highlightColor == null
        ? baseCardColor
        : Color.alphaBlend(highlightColor!.withOpacity(0.08), baseCardColor);
    final borderColor = highlightColor == null
        ? const Color(0xFFE2E8F0)
        : highlightColor!.withOpacity(0.32);

    return Card(
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        side: BorderSide(
          color: borderColor,
          width: highlightColor == null ? 1 : 1.2,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                  StatusBadge(label: status.toUpperCase(), status: status),
                ],
              ),
              if (description != null && description!.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  description!,
                  style: muted,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  _InfoPill(icon: Icons.timer_outlined, label: '$duration min'),
                  _InfoPill(
                    icon: Icons.help_outline,
                    label: '$questions questions',
                  ),
                ],
              ),
              if (actionLabel != null ||
                  (destructiveActionLabel != null &&
                      onDestructiveAction != null)) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (actionLabel != null)
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: actionEnabled ? onAction : null,
                          icon: Icon(
                            actionIcon ??
                                (status == 'draft'
                                    ? Icons.publish_outlined
                                    : Icons.archive_outlined),
                            size: 18,
                          ),
                          label: Text(actionLabel!),
                        ),
                      ),
                    if (actionLabel != null &&
                        destructiveActionLabel != null &&
                        onDestructiveAction != null)
                      const SizedBox(width: 10),
                    if (destructiveActionLabel != null &&
                        onDestructiveAction != null)
                      OutlinedButton.icon(
                        onPressed: onDestructiveAction,
                        icon: const Icon(
                          Icons.delete_outline,
                          size: 18,
                          color: AppTheme.errorColor,
                        ),
                        label: Text(
                          destructiveActionLabel!,
                          style: const TextStyle(color: AppTheme.errorColor),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppTheme.surfaceMuted,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: const Color(0xFF64748B)),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
