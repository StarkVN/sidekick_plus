import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:sidekick/src/modules/common/utils/helpers.dart';
import 'package:sidekick/src/modules/common/utils/notify.dart';
import 'package:sidekick/src/modules/common/utils/open_link.dart';

import 'cleaner.provider.dart';
import 'models/clean_target.dart';
import 'services/cleaner.service.dart';

/// Top-level screen for Memory & Cache Cleaner on macOS
class CleanerScreen extends HookConsumerWidget {
  /// Constructor
  const CleanerScreen({super.key});

  IconData _getCategoryIcon(CleanCategory category) {
    switch (category) {
      case CleanCategory.xcode:
        return LucideIcons.hammer300;
      case CleanCategory.flutter:
        return LucideIcons.layers300;
      case CleanCategory.android:
        return LucideIcons.smartphone300;
      case CleanCategory.docker:
        return LucideIcons.box300;
    }
  }

  Future<void> _confirmAndClean(
    BuildContext context,
    WidgetRef ref,
    CleanTarget target,
  ) async {
    if (target.isDangerous) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Row(
            children: [
              const Icon(
                LucideIcons.triangleAlert300,
                color: Colors.orange,
                size: 22,
              ),
              const SizedBox(width: 10),
              Text(
                dialogContext.i18n(
                  'modules:cleaner.confirmTitle',
                  variables: {'title': target.getTitle(dialogContext)},
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                target.getDescription(dialogContext),
                style: const TextStyle(fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(
                    dialogContext,
                  ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dialogContext.i18n('modules:cleaner.command'),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    SelectableText(
                      target.commandPreview,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: Colors.cyanAccent,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                dialogContext.i18n('modules:cleaner.confirmPrompt'),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(dialogContext.i18n('modules:cleaner.cancel')),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.orange.shade800,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(dialogContext.i18n('modules:cleaner.confirm')),
            ),
          ],
        ),
      );

      if (confirmed != true) return;
    }

    final result = await ref
        .read(cleanerProvider.notifier)
        .cleanTarget(target.id);
    if (!context.mounted) return;
    if (result.success) {
      notify(
        context.i18n(
          'modules:cleaner.cleanSuccess',
          variables: {'size': CleanerService.formatBytes(result.freedBytes)},
        ),
      );
    } else {
      notifyError(
        context.i18n(
          'modules:cleaner.cleanError',
          variables: {'error': result.message},
        ),
      );
    }
  }

  Future<void> _cleanAllSafe(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            const Icon(
              LucideIcons.sparkles300,
              color: Colors.greenAccent,
              size: 22,
            ),
            const SizedBox(width: 10),
            Text(dialogContext.i18n('modules:cleaner.cleanAllSafeDialogTitle')),
          ],
        ),
        content: Text(
          dialogContext.i18n('modules:cleaner.cleanAllSafeDialogContent'),
          style: const TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(dialogContext.i18n('modules:cleaner.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(dialogContext.i18n('modules:cleaner.startSafeClean')),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final results = await ref.read(cleanerProvider.notifier).cleanAllSafe();
      final totalFreed = results.fold<int>(0, (sum, r) => sum + r.freedBytes);
      if (!context.mounted) return;
      notify(
        context.i18n(
          'modules:cleaner.cleanAllSafeCompleted',
          variables: {'size': CleanerService.formatBytes(totalFreed)},
        ),
      );
    }
  }

  Future<void> _showProjectsDialog(BuildContext context, WidgetRef ref) async {
    await showDialog(
      context: context,
      builder: (dialogContext) {
        Future<Map<String, int>> projectsFuture = CleanerService.instance
            .findFlutterProjectsWithBuildCache();
        final cleaningProjects = <String>{};

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  const Icon(LucideIcons.layers300, size: 22),
                  const SizedBox(width: 10),
                  Text(
                    dialogContext.i18n('modules:cleaner.projectsDialogTitle'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 650,
                child: FutureBuilder<Map<String, int>>(
                  future: projectsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const SizedBox(
                        height: 200,
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }

                    final projects = snapshot.data ?? {};
                    if (projects.isEmpty) {
                      return SizedBox(
                        height: 120,
                        child: Center(
                          child: Text(
                            dialogContext.i18n(
                              'modules:cleaner.noProjectsWithCache',
                            ),
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).textTheme.bodySmall?.color,
                            ),
                          ),
                        ),
                      );
                    }

                    final sortedEntries = projects.entries.toList()
                      ..sort((a, b) => b.value.compareTo(a.value));

                    return ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 450),
                      child: CupertinoScrollbar(
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: sortedEntries.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final entry = sortedEntries[index];
                            final path = entry.key;
                            final size = entry.value;
                            final projectName = path
                                .split(Platform.pathSeparator)
                                .last;
                            final isCleaning = cleaningProjects.contains(path);

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest
                                      .withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Icon(
                                  LucideIcons.folder300,
                                  size: 18,
                                ),
                              ),
                              title: Text(
                                projectName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              subtitle: SelectableText(
                                path,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontFamily: 'monospace',
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.color
                                      ?.withValues(alpha: 0.7),
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .secondaryContainer
                                          .withValues(alpha: 0.5),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      CleanerService.formatBytes(size),
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSecondaryContainer,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  IconButton(
                                    icon: const Icon(
                                      LucideIcons.folderOpen300,
                                      size: 18,
                                    ),
                                    tooltip: dialogContext.i18n(
                                      'modules:cleaner.openInFinder',
                                    ),
                                    onPressed: () => openPath(path),
                                  ),
                                  if (isCleaning)
                                    const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: Padding(
                                        padding: EdgeInsets.all(4),
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    )
                                  else
                                    IconButton(
                                      icon: const Icon(
                                        LucideIcons.trash2300,
                                        size: 18,
                                        color: Colors.orange,
                                      ),
                                      tooltip: dialogContext.i18n(
                                        'modules:cleaner.cleanProject',
                                      ),
                                      onPressed: () async {
                                        setDialogState(() {
                                          cleaningProjects.add(path);
                                        });

                                        final result = await CleanerService
                                            .instance
                                            .cleanSingleProject(path);

                                        setDialogState(() {
                                          cleaningProjects.remove(path);
                                          projectsFuture = CleanerService
                                              .instance
                                              .findFlutterProjectsWithBuildCache();
                                        });

                                        // Refresh global cleaner state
                                        await ref
                                            .read(cleanerProvider.notifier)
                                            .scanAll(force: true);

                                        if (result.success && dialogContext.mounted) {
                                          notify(
                                            dialogContext.i18n(
                                              'modules:cleaner.cleanSuccess',
                                              variables: {
                                                'size':
                                                    CleanerService.formatBytes(
                                                      result.freedBytes,
                                                    ),
                                              },
                                            ),
                                          );
                                        }
                                      },
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(dialogContext.i18n('modules:cleaner.close')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scrollController = useScrollController();
    final state = ref.watch(cleanerProvider);
    final notifier = ref.read(cleanerProvider.notifier);
    final totalReclaimable = CleanerService.formatBytes(
      state.totalReclaimableBytes,
    );
    final totalSafeReclaimable = CleanerService.formatBytes(
      state.totalSafeReclaimableBytes,
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CupertinoScrollbar(
        controller: scrollController,
        child: SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 850),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Banner tổng quan
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(
                            context,
                          ).colorScheme.primaryContainer.withValues(alpha: 0.4),
                          Theme.of(context).colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.2),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.outlineVariant.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.secondary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                LucideIcons.hardDrive300,
                                size: 28,
                                color: Theme.of(context).colorScheme.secondary,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    context.i18n('modules:cleaner.headerTitle'),
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    context.i18n(
                                      'modules:cleaner.headerDescription',
                                    ),
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.color
                                              ?.withValues(alpha: 0.8),
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Divider(height: 1),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  context.i18n(
                                    'modules:cleaner.safeReclaimable',
                                  ),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text(
                                      totalSafeReclaimable,
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.secondary,
                                      ),
                                    ),
                                    if (state.totalReclaimableBytes >
                                        state.totalSafeReclaimableBytes) ...[
                                      const SizedBox(width: 8),
                                      Text(
                                        context.i18n(
                                          'modules:cleaner.total',
                                          variables: {'size': totalReclaimable},
                                        ),
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.color
                                              ?.withValues(alpha: 0.6),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                OutlinedButton.icon(
                                  onPressed: state.isScanningAll
                                      ? null
                                      : () => notifier.scanAll(force: true),
                                  icon: state.isScanningAll
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(
                                          LucideIcons.refreshCw300,
                                          size: 16,
                                        ),
                                  label: Text(
                                    state.isScanningAll
                                        ? context.i18n(
                                            'modules:cleaner.scanning',
                                          )
                                        : context.i18n('modules:cleaner.scan'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                FilledButton.icon(
                                  onPressed:
                                      (state.isCleaningAny ||
                                          state.totalSafeReclaimableBytes == 0)
                                      ? null
                                      : () => _cleanAllSafe(context, ref),
                                  icon: const Icon(
                                    LucideIcons.sparkles300,
                                    size: 16,
                                  ),
                                  label: Text(
                                    context.i18n(
                                      'modules:cleaner.cleanAllSafe',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    context.i18n('modules:cleaner.availableTargets'),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Danh sách các Target
                  ...state.targets.map((target) {
                    final formattedSize = target.sizeInBytes != null
                        ? CleanerService.formatBytes(target.sizeInBytes!)
                        : (target.isCalculating
                              ? context.i18n('modules:cleaner.calculating')
                              : context.i18n('modules:cleaner.notScanned'));

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Theme.of(
                            context,
                          ).dividerColor.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  _getCategoryIcon(target.category),
                                  size: 20,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.secondary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            target.getTitle(context),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: target.isDangerous
                                                ? Colors.orange.withValues(
                                                    alpha: 0.15,
                                                  )
                                                : Colors.green.withValues(
                                                    alpha: 0.15,
                                                  ),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: Text(
                                            target.isDangerous
                                                ? context.i18n(
                                                    'modules:cleaner.confirmNeeded',
                                                  )
                                                : context.i18n(
                                                    'modules:cleaner.safe100',
                                                  ),
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: target.isDangerous
                                                  ? Colors.orange
                                                  : Colors.green,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      target.getSubtitle(context),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.color
                                            ?.withValues(alpha: 0.7),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            target.getDescription(context),
                            style: const TextStyle(fontSize: 13, height: 1.3),
                          ),
                          const SizedBox(height: 10),
                          // Path và Command Preview
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest
                                  .withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(LucideIcons.folder300, size: 12),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        target.targetPath,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontFamily: 'monospace',
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(
                                      LucideIcons.terminal300,
                                      size: 12,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        target.commandPreview,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontFamily: 'monospace',
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.secondary,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Footer: Dung lượng và nút Dọn dẹp
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    context.i18n('modules:cleaner.size'),
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  if (target.isCalculating)
                                    const SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  else
                                    Text(
                                      formattedSize,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: (target.sizeInBytes ?? 0) > 0
                                            ? Theme.of(
                                                context,
                                              ).colorScheme.secondary
                                            : Theme.of(
                                                context,
                                              ).textTheme.bodySmall?.color,
                                      ),
                                    ),
                                  if (target.isCleaned) ...[
                                    const SizedBox(width: 8),
                                    Row(
                                      children: [
                                        const Icon(
                                          LucideIcons.check300,
                                          size: 14,
                                          color: Colors.green,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          context.i18n(
                                            'modules:cleaner.cleaned',
                                          ),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.green,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (target.id ==
                                      'flutter_projects_build') ...[
                                    OutlinedButton.icon(
                                      onPressed: () =>
                                          _showProjectsDialog(context, ref),
                                      icon: const Icon(
                                        LucideIcons.list300,
                                        size: 14,
                                      ),
                                      label: Text(
                                        context.i18n(
                                          'modules:cleaner.viewProjects',
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  FilledButton.tonal(
                                    onPressed:
                                        (target.isCleaning ||
                                            (target.sizeInBytes ?? 0) == 0)
                                        ? null
                                        : () => _confirmAndClean(
                                            context,
                                            ref,
                                            target,
                                          ),
                                    child: target.isCleaning
                                        ? const SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : Text(
                                            context.i18n(
                                              'modules:cleaner.cleanThisItem',
                                            ),
                                          ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
