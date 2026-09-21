import 'dart:io';

import 'package:window_manager/window_manager.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:sidekick/src/components/atoms/typography.dart';
import 'package:sidekick/src/modules/common/constants.dart';
import 'package:sidekick/src/modules/navigation/navigation.provider.dart';
import 'package:sidekick/src/modules/updater/components/update_button.dart';
import 'package:sidekick/src/window_border.dart';

/// Sidekick top app bar
class SkAppBar extends ConsumerWidget implements PreferredSizeWidget {
  /// Constructor
  const SkAppBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(45);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    /// Opens up search modal
    void openSearchModal() {
      ref.read(navigationProvider.notifier).goTo(NavigationRoutes.searchScreen);
    }

    Widget renderTitle() {
      if (!Platform.isMacOS) {
        return const Row(children: [SizedBox(width: 10), Caption(kAppTitle)]);
      }
      return const Caption(kAppTitle);
    }

    return AppBar(
      // backgroundColor: platformBackgroundColor(context),
      backgroundColor: Colors.transparent,
      title: renderTitle(),
      centerTitle: Platform.isWindows ? false : true,
      titleSpacing: 0,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: Platform.isMacOS ? const WindowButtons() : null,
      actions: [
        const SkUpdateButton(),
        const SizedBox(width: 10),
        IconButton(
          icon: const Icon(LucideIcons.search300),
          iconSize: 20,
          splashRadius: 15,
          onPressed: openSearchModal,
        ),
        const SizedBox(width: 10),
        if (!Platform.isMacOS) const WindowButtons(),
      ],
      bottom: !Platform.isWindows
          ? const PreferredSize(
              preferredSize: Size.fromHeight(1),
              child: Divider(height: 0, thickness: 0.5),
            )
          : null,
      automaticallyImplyLeading: false,
      // shadowColor: Colors.transparent,
      // backgroundColor: Colors.transparent,
      flexibleSpace: const DragToMoveArea(child: SizedBox.expand()),
    );
  }
}
