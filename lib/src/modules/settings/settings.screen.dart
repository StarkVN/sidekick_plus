import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../modules/common/utils/helpers.dart';
import '../../modules/common/utils/notify.dart';
import 'scenes/about_settings.scene.dart';
import 'scenes/flutter_settings.scene.dart';
import 'scenes/fvm_settings.scene.dart';
import 'scenes/general_settings.scene.dart';
import 'settings.provider.dart';

/// TODO: Unify the nav sections information
/// Nav sections
enum NavSection {
  /// General
  general,

  /// FVM
  fvm,

  /// Flutter
  flutter,

  /// About
  about,
}

final _sectionIcons = [
  LucideIcons.slidersHorizontal300,
  LucideIcons.layers300,
  LucideIcons.terminal300,
  LucideIcons.info300,
];

/// Settings screen
class SettingsScreen extends HookConsumerWidget {
  /// Constructor
  const SettingsScreen({
    this.section = NavSection.general,
    super.key,
  });

  /// Current nav section
  final NavSection section;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = ref.watch(settingsProvider.notifier);
    final settings = ref.watch(settingsProvider);

    final tabController = useTabController(
      initialLength: 4,
      initialIndex: section.index,
    );

    useEffect(() {
      if (tabController.index != section.index) {
        tabController.animateTo(section.index);
      }
      return;
    }, [section]);

    final sections = [
      context.i18n('modules:settings.scenes.general'),
      'FVM',
      'Flutter',
      context.i18n('modules:settings.scenes.about'),
    ];

    Future<void> handleSave() async {
      final savedMessage =
          context.i18n('modules:settings.settingsHaveBeenSaved');
      final errorMessage =
          context.i18n('modules:settings.couldNotSaveSettings');
      try {
        await provider.save(settings);
        notify(savedMessage);
      } on Exception catch (e) {
        notifyError(errorMessage);
        notifyError(e.toString());
      }
    }

    return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).dividerColor,
                  width: 1,
                ),
              ),
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                constraints: const BoxConstraints(maxWidth: 850),
                child: TabBar(
                  controller: tabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  dividerColor: Colors.transparent,
                  indicatorColor: Theme.of(context).colorScheme.secondary,
                  labelColor: Theme.of(context).colorScheme.secondary,
                  unselectedLabelColor: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.color
                      ?.withValues(alpha: 0.7),
                  indicatorWeight: 2.5,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontWeight: FontWeight.normal,
                    fontSize: 14,
                  ),
                  tabs: sections.mapIndexed(
                    (sectionName, idx) => Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_sectionIcons[idx], size: 16),
                          const SizedBox(width: 8),
                          Text(sectionName),
                        ],
                      ),
                    ),
                  ).toList(),
                ),
              ),
            ),
          ),
          Expanded(
            child: Align(
              alignment: Alignment.topLeft,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 850),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TabBarView(
                  controller: tabController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    SettingsSectionGeneral(settings, handleSave),
                    FvmSettingsScene(settings, handleSave),
                    SettingsSectionFlutter(settings, handleSave),
                    const AboutSettingsScene(),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
  }
}
