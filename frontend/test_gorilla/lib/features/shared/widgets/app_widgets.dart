import 'package:flutter/material.dart';

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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          if (message != null) ...[SizedBox(height: 16), Text(message!)],
        ],
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
    return Center(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red),
            SizedBox(height: 16),
            Text('Error', style: Theme.of(context).textTheme.headlineSmall),
            SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (onRetry != null) ...[
              SizedBox(height: 24),
              ElevatedButton(onPressed: onRetry, child: Text('Retry')),
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey[400]),
          SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          if (subtitle != null) ...[
            SizedBox(height: 8),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
            ),
          ],
          if (onAction != null && actionLabel != null) ...[
            SizedBox(height: 24),
            ElevatedButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
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
  final VoidCallback onTap;
  final String? actionLabel;
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
    required this.onTap,
    this.actionLabel,
    this.onAction,
    this.destructiveActionLabel,
    this.onDestructiveAction,
  }) : super(key: key);

  Color getStatusColor() {
    switch (status) {
      case 'published':
        return Colors.green;
      case 'draft':
        return Colors.orange;
      case 'archived':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: getStatusColor().withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: getStatusColor(),
                      ),
                    ),
                  ),
                ],
              ),
              if (description != null) ...[
                SizedBox(height: 8),
                Text(
                  description!,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.timer_outlined, size: 16, color: Colors.grey),
                  SizedBox(width: 4),
                  Text(
                    '$duration min',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  SizedBox(width: 16),
                  Icon(Icons.help_outline, size: 16, color: Colors.grey),
                  SizedBox(width: 4),
                  Text(
                    '$questions questions',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              if ((actionLabel != null && onAction != null) ||
                  (destructiveActionLabel != null &&
                      onDestructiveAction != null)) ...[
                SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(
                    spacing: 8,
                    children: [
                      if (actionLabel != null && onAction != null)
                        TextButton.icon(
                          onPressed: onAction,
                          icon: Icon(
                            status == 'draft'
                                ? Icons.publish_outlined
                                : Icons.archive_outlined,
                            size: 18,
                          ),
                          label: Text(actionLabel!),
                        ),
                      if (destructiveActionLabel != null &&
                          onDestructiveAction != null)
                        TextButton.icon(
                          onPressed: onDestructiveAction,
                          icon: const Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: Colors.red,
                          ),
                          label: Text(
                            destructiveActionLabel!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
