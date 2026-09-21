import 'dart:io';

import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:sidekick/src/components/organisms/app_bottom_bar.dart';
import 'package:sidekick/src/components/atoms/typography.dart';
import 'package:sidekick/src/modules/common/utils/helpers.dart';
import 'package:sidekick/src/modules/common/utils/indexed_transition_switcher.dart';
import 'package:sidekick/src/modules/common/utils/notify.dart';
import 'package:sidekick/src/modules/compatibility_checks/compat.provider.dart';
import 'package:sidekick/src/modules/compatibility_checks/compat.screen.dart';
import 'package:sidekick/src/modules/search/components/search_bar.dart' as sb;
import 'package:sidekick/src/modules/selected_detail/components/info_drawer.dart';
import 'package:sidekick/src/modules/settings/settings.screen.dart';
import 'package:sidekick/src/version.dart';

import '../../components/molecules/top_app_bar.dart';
import '../../components/organisms/shortcut_manager.dart';
import '../../modules/common/utils/layout_size.dart';
import '../../theme.dart';
import '../cleaner/cleaner.screen.dart';
import '../fvm/fvm.screen.dart';
import '../navigation/navigation.provider.dart';
import '../news/news.provider.dart';
import '../news/news.screen.dart';
import '../projects/projects.screen.dart';
import '../releases/releases.screen.dart';
import '../selected_detail/selected_detail.provider.dart';
import 'constants.dart';

final _scaffoldKey = GlobalKey<ScaffoldState>();

NavigationRoutes _getRouteFromIndex(int index, bool isMac) {
  if (isMac) {
    return NavigationRoutes.values[index];
  }
  if (index == 4) return NavigationRoutes.settingsScreen;
  return NavigationRoutes.values[index];
}

int _getIndexFromRoute(NavigationRoutes route, bool isMac) {
  if (isMac) {
    return route.index;
  }
  if (route == NavigationRoutes.settingsScreen) return 4;
  return route.index;
}

/// Main widget of the app
class AppShell extends HookConsumerWidget {
  /// Constructor
  const AppShell({super.key});

  NavigationRailDestination renderNavButton(
    BuildContext context,
    String label,
    IconData iconData,
  ) {
    return NavigationRailDestination(
      icon: Icon(iconData, size: 20),
      selectedIcon: Icon(
        iconData,
        size: 20,
        color: Theme.of(context).colorScheme.secondary,
      ),
      label: Text(label),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    LayoutSize.init(context);
    final navigation = ref.watch(navigationProvider.notifier);
    final currentRoute = ref.watch(navigationProvider);
    final selectedInfo = ref.watch(selectedDetailProvider);
    final compatInfo = ref.watch(compatProvider);
    final newsState = ref.watch(flutterNewsProvider);
    final focusNode = useFocusNode();

    // Index of item selected
    final selectedIndex = useState(0);
    final isMac = Platform.isMacOS;

    final pages = [
      const FVMScreen(),
      const ProjectsScreen(),
      const ReleasesScreen(),
      const NewsScreen(),
      if (isMac) const CleanerScreen(),
      const SettingsScreen(),
    ];

    // Side effect when route changes
    useEffect(() {
      // Do not set index if its search
      if (currentRoute != NavigationRoutes.searchScreen) {
        selectedIndex.value = _getIndexFromRoute(currentRoute, isMac);
      }
      return;
    }, [currentRoute, isMac]);

    // Side effect when info is selected
    useEffect(() {
      if (_scaffoldKey.currentState == null) return;
      final isOpen = _scaffoldKey.currentState?.isEndDrawerOpen;
      final hasInfo = selectedInfo?.release != null;

      // Open drawer if not large layout and its not open
      if (hasInfo && isOpen != true) {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          _scaffoldKey.currentState?.openEndDrawer();
        });
      }
      return;
    }, [selectedInfo]);

    if (!compatInfo.ready && !compatInfo.waiting) {
      notify("Sidekick is missing key components to work", error: true);
      Future.delayed(Duration.zero).then((value) {
        if (context.mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const CompatCheckScreen()),
          );
        }
      });
    }

    return SkShortcutManager(
      focusNode: focusNode,
      child: Scaffold(
        appBar: const SkAppBar(),
        bottomNavigationBar: const AppBottomBar(),
        endDrawer: const SelectedDetailDrawer(),
        backgroundColor: platformBackgroundColor(context),
        key: _scaffoldKey,
        body: Row(
          children: [
            NavigationRail(
              key: Key("NavigationRail${selectedIndex.value}"),
              backgroundColor: platformBackgroundColor(context),
              selectedIndex: selectedIndex.value,
              minWidth: kNavigationWidth,
              minExtendedWidth: kNavigationWidthExtended,
              extended: !LayoutSize.isSmall,
              trailingAtBottom: true,
              onDestinationSelected: (index) {
                navigation.goTo(_getRouteFromIndex(index, isMac));
              },
              trailing: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Caption(packageVersion),
              ),
              destinations: [
                renderNavButton(
                  context,
                  context.i18n('modules:common.navButtonDashboard'),
                  LucideIcons.layoutDashboard300,
                ),
                renderNavButton(
                  context,
                  context.i18n('modules:common.navButtonProjects'),
                  LucideIcons.folders300,
                ),
                renderNavButton(
                  context,
                  context.i18n('modules:common.navButtonReleases'),
                  LucideIcons.rocket300,
                ),
                NavigationRailDestination(
                  icon: Badge.count(
                    count: newsState.unreadCount,
                    isLabelVisible: newsState.unreadCount > 0,
                    child: const Icon(LucideIcons.newspaper300, size: 20),
                  ),
                  selectedIcon: Badge.count(
                    count: newsState.unreadCount,
                    isLabelVisible: newsState.unreadCount > 0,
                    child: Icon(
                      LucideIcons.newspaper300,
                      size: 20,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                  label: Text(context.i18n('modules:common.navButtonNews')),
                ),
                if (isMac)
                  renderNavButton(
                    context,
                    context.i18n('modules:cleaner.title'),
                    LucideIcons.hardDrive300,
                  ),
                renderNavButton(
                  context,
                  context.i18n('modules:common.settings'),
                  LucideIcons.settings300,
                ),
              ],
            ),
            if (!Platform.isWindows)
              const VerticalDivider(thickness: 1, width: 1),
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: Platform.isWindows
                          ? const BorderRadius.only(
                              topLeft: Radius.circular(12),
                            )
                          : null,
                      border: Platform.isWindows
                          ? Border.all(color: Theme.of(context).dividerColor)
                          : null,
                    ),
                    clipBehavior: Clip.antiAliasWithSaveLayer,
                    child: ClipRRect(
                      // This is the main content.
                      borderRadius: Platform.isWindows
                          ? const BorderRadius.only(
                              topLeft: Radius.circular(12),
                            )
                          : BorderRadius.zero,
                      child: IndexedTransitionSwitcher(
                        // Need to update IndexTransitionSwitcher on theme change
                        key: Key(Theme.of(context).brightness.toString()),
                        duration: const Duration(milliseconds: 250),
                        reverse:
                            selectedIndex.value < (navigation.previous.index),
                        transitionBuilder:
                            (child, animation, secondaryAnimation) {
                              return SharedAxisTransition(
                                fillColor:
                                    Theme.of(context).brightness ==
                                        Brightness.light
                                    ? lightTheme.scaffoldBackgroundColor
                                    : darkTheme.scaffoldBackgroundColor,
                                animation: animation,
                                secondaryAnimation: secondaryAnimation,
                                transitionType:
                                    SharedAxisTransitionType.vertical,
                                child: child,
                              );
                            },
                        index: selectedIndex.value,
                        children: pages,
                      ),
                    ),
                  ),
                  const sb.SearchBar(),
                ],
              ),
            ),
            // TODO Version
          ],
        ),
      ),
    );
  }
}
