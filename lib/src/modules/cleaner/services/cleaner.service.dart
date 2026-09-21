import 'dart:io';

import '../models/clean_target.dart';

/// Service responsible for scanning and cleaning developer caches on macOS
class CleanerService {
  /// Singleton instance
  static final CleanerService instance = CleanerService._();
  CleanerService._();

  /// User's HOME directory
  String get homeDir => Platform.environment['HOME'] ?? '';

  /// Formats raw bytes into a human readable string
  static String formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    double count = bytes.toDouble();
    while (count >= 1024 && i < suffixes.length - 1) {
      count /= 1024;
      i++;
    }
    return '${count.toStringAsFixed(i > 1 ? 1 : 0)} ${suffixes[i]}';
  }

  /// Calculates size of a path in bytes using macOS native `du -sk`
  Future<int> getPathSize(String path) async {
    final resolved = _resolvePath(path);
    final dir = Directory(resolved);
    final file = File(resolved);

    if (!await dir.exists() && !await file.exists()) {
      return 0;
    }

    try {
      final result = await Process.run('du', ['-sk', resolved]);
      if (result.exitCode == 0) {
        final output = result.stdout.toString().trim();
        final firstToken = output.split(RegExp(r'\s+')).first;
        final kb = int.tryParse(firstToken) ?? 0;
        return kb * 1024;
      }
    } catch (_) {
      // Fallback: ignore error and return 0
    }
    return 0;
  }

  /// Checks if a command-line tool exists in the environment
  Future<bool> isCommandAvailable(String command) async {
    try {
      final result = await Process.run('which', [command]);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  /// Resolves `~` to the full HOME directory path
  String _resolvePath(String path) {
    if (path.startsWith('~/')) {
      return path.replaceFirst('~', homeDir);
    }
    return path;
  }

  /// Initial list of supported clean targets for macOS
  List<CleanTarget> getInitialTargets() {
    return [
      const CleanTarget(
        id: 'flutter_projects_build',
        titleKey: 'modules:cleaner.targets.flutterProjectsBuild.title',
        subtitleKey: 'modules:cleaner.targets.flutterProjectsBuild.subtitle',
        category: CleanCategory.flutter,
        targetPath: '~/... (All Flutter Projects)',
        commandPreview: 'flutter clean (in projects with build cache)',
        descriptionKey:
            'modules:cleaner.targets.flutterProjectsBuild.description',
        isDangerous: false,
      ),
      const CleanTarget(
        id: 'xcode_derived_data',
        titleKey: 'modules:cleaner.targets.xcodeDerivedData.title',
        subtitleKey: 'modules:cleaner.targets.xcodeDerivedData.subtitle',
        category: CleanCategory.xcode,
        targetPath: '~/Library/Developer/Xcode/DerivedData',
        commandPreview: 'rm -rf ~/Library/Developer/Xcode/DerivedData/*',
        descriptionKey: 'modules:cleaner.targets.xcodeDerivedData.description',
        isDangerous: false,
      ),
      const CleanTarget(
        id: 'xcode_caches',
        titleKey: 'modules:cleaner.targets.xcodeCaches.title',
        subtitleKey: 'modules:cleaner.targets.xcodeCaches.subtitle',
        category: CleanCategory.xcode,
        targetPath: '~/Library/Caches/com.apple.dt.Xcode',
        commandPreview: 'rm -rf ~/Library/Caches/com.apple.dt.Xcode/*',
        descriptionKey: 'modules:cleaner.targets.xcodeCaches.description',
        isDangerous: false,
      ),
      const CleanTarget(
        id: 'simulator_unavailable',
        titleKey: 'modules:cleaner.targets.simulatorUnavailable.title',
        subtitleKey: 'modules:cleaner.targets.simulatorUnavailable.subtitle',
        category: CleanCategory.xcode,
        targetPath: '~/Library/Developer/CoreSimulator/Caches',
        commandPreview:
            'xcrun simctl delete unavailable && rm -rf ~/Library/Developer/CoreSimulator/Caches/*',
        descriptionKey:
            'modules:cleaner.targets.simulatorUnavailable.description',
        isDangerous: false,
      ),
      const CleanTarget(
        id: 'flutter_pub_cache',
        titleKey: 'modules:cleaner.targets.flutterPubCache.title',
        subtitleKey: 'modules:cleaner.targets.flutterPubCache.subtitle',
        category: CleanCategory.flutter,
        targetPath: '~/.pub-cache',
        commandPreview: 'flutter pub cache clean --force',
        descriptionKey: 'modules:cleaner.targets.flutterPubCache.description',
        isDangerous: false,
      ),
      const CleanTarget(
        id: 'android_gradle_cache',
        titleKey: 'modules:cleaner.targets.androidGradleCache.title',
        subtitleKey: 'modules:cleaner.targets.androidGradleCache.subtitle',
        category: CleanCategory.android,
        targetPath: '~/.gradle/caches',
        commandPreview: 'rm -rf ~/.gradle/caches/ && rm -rf ~/.gradle/daemon/',
        descriptionKey:
            'modules:cleaner.targets.androidGradleCache.description',
        isDangerous: false,
      ),
      const CleanTarget(
        id: 'android_ndk',
        titleKey: 'modules:cleaner.targets.androidNdk.title',
        subtitleKey: 'modules:cleaner.targets.androidNdk.subtitle',
        category: CleanCategory.android,
        targetPath: '~/Library/Android/sdk/ndk',
        commandPreview: 'rm -rf ~/Library/Android/sdk/ndk/*',
        descriptionKey: 'modules:cleaner.targets.androidNdk.description',
        isDangerous: true,
      ),
      const CleanTarget(
        id: 'docker_system_prune',
        titleKey: 'modules:cleaner.targets.dockerSystemPrune.title',
        subtitleKey: 'modules:cleaner.targets.dockerSystemPrune.subtitle',
        category: CleanCategory.docker,
        targetPath: 'Docker Engine',
        commandPreview: 'docker system prune -f',
        descriptionKey:
            'modules:cleaner.targets.dockerSystemPrune.description',
        isDangerous: true,
      ),
    ];
  }

  /// Finds all Flutter projects in HOME directory that have non-empty build caches.
  /// Returns a Map of project directory path to build directory size in bytes.
  Future<Map<String, int>> findFlutterProjectsWithBuildCache() async {
    final home = homeDir;
    if (home.isEmpty) return {};

    try {
      final result = await Process.run(
        'mdfind',
        ['-onlyin', home, 'kMDItemFSName == \'pubspec.yaml\''],
      );

      if (result.exitCode != 0) return {};

      final lines = result.stdout.toString().split('\n');
      const ignoreSubstrings = [
        '/.pub-cache/',
        '/fvm/versions/',
        '/bin/cache/',
        '/.git/',
        '/.symlinks/',
        '/.dart_tool/',
        '/Pods/',
        '/DerivedData/',
        '/Library/',
        '/.Trash/',
        '/.antigravity-ide/',
        '/.gemini/',
        '/SourcePackages/',
        '/node_modules/',
        '/third_party/',
        '/.gradle/',
      ];

      final projectsWithCache = <String, int>{};
      final currentExe = Platform.resolvedExecutable;

      for (var line in lines) {
        line = line.trim();
        if (line.isEmpty) continue;

        if (ignoreSubstrings.any((sub) => line.contains(sub))) {
          continue;
        }

        final pubspecFile = File(line);
        final projectDir = pubspecFile.parent.path;

        // Skip if inside another project's build directory (e.g. SPM checkout)
        if (projectDir.contains('/build/')) {
          continue;
        }

        // Avoid cleaning the currently running application project
        if (currentExe.isNotEmpty && currentExe.startsWith(projectDir)) {
          continue;
        }

        final buildDir = Directory('$projectDir/build');
        if (!buildDir.existsSync()) {
          continue;
        }

        try {
          // Check if build dir has substantial build artifacts (> 1MB)
          final size = await getPathSize(buildDir.path);
          if (size > 1024 * 1024) {
            projectsWithCache[projectDir] = size;
          }
        } catch (_) {
          continue;
        }
      }

      return projectsWithCache;
    } catch (_) {
      return {};
    }
  }

  /// Calculates size for a target
  /// Calculates size for a target with modification-based caching
  Future<CleanTarget> scanTarget(CleanTarget target, {bool force = false}) async {
    if (target.id == 'flutter_projects_build') {
      if (!force && target.sizeInBytes != null) {
        return target.copyWith(isCalculating: false);
      }

      final projectsMap = await findFlutterProjectsWithBuildCache();
      final totalSize = projectsMap.values.fold<int>(0, (sum, sz) => sum + sz);

      return target.copyWith(
        sizeInBytes: totalSize,
        lastModifiedTimestamp: DateTime.now().millisecondsSinceEpoch,
        isCalculating: false,
        isAvailable: true,
      );
    }

    if (target.id == 'docker_system_prune') {
      if (!force && target.sizeInBytes != null) {
        return target.copyWith(isCalculating: false);
      }
      final hasDocker = await isCommandAvailable('docker');
      if (!hasDocker) {
        return target.copyWith(
          isAvailable: false,
          sizeInBytes: 0,
          isCalculating: false,
        );
      }
      // Calculate reclaimable docker space if docker is running
      try {
        final result = await Process.run('docker', ['system', 'df']);
        if (result.exitCode == 0) {
          return target.copyWith(
            isAvailable: true,
            isCalculating: false,
          );
        } else {
          return target.copyWith(
            isAvailable: false,
            sizeInBytes: 0,
            isCalculating: false,
          );
        }
      } catch (_) {
        return target.copyWith(
          isAvailable: false,
          sizeInBytes: 0,
          isCalculating: false,
        );
      }
    }

    final resolved = _resolvePath(target.targetPath);
    final dir = Directory(resolved);
    final file = File(resolved);

    final isDir = await dir.exists();
    final isFile = !isDir && await file.exists();

    if (!isDir && !isFile) {
      return target.copyWith(
        sizeInBytes: 0,
        lastModifiedTimestamp: 0,
        isCalculating: false,
        isAvailable: false,
      );
    }

    int currentModified = 0;
    try {
      final stat = isDir ? await dir.stat() : await file.stat();
      currentModified = stat.modified.millisecondsSinceEpoch;
    } catch (_) {}

    // Check if we can reuse the cached size
    if (!force &&
        target.sizeInBytes != null &&
        target.lastModifiedTimestamp != null &&
        target.lastModifiedTimestamp == currentModified) {
      // Directory has not changed since last scan, reuse cached size!
      return target.copyWith(
        isCalculating: false,
        isAvailable: true,
      );
    }

    final size = await getPathSize(resolved);
    return target.copyWith(
      sizeInBytes: size,
      lastModifiedTimestamp: currentModified,
      isCalculating: false,
      isAvailable: true,
    );
  }

  /// Cleans a specific target
  Future<CleanResult> cleanTarget(CleanTarget target) async {
    try {
      final initialSize = target.sizeInBytes ?? 0;
      switch (target.id) {
        case 'flutter_projects_build':
          final projectsMap = await findFlutterProjectsWithBuildCache();
          var totalFreed = 0;
          for (final entry in projectsMap.entries) {
            final projDir = entry.key;
            final prevSize = entry.value;

            // 1. Run flutter clean with timeout in project directory
            try {
              await Process.run(
                'flutter',
                ['clean'],
                workingDirectory: projDir,
                runInShell: true,
              ).timeout(const Duration(seconds: 15));
            } catch (_) {}

            // 2. Guarantee deletion of build directory if any leftovers remain
            final buildDir = Directory('$projDir/build');
            if (await buildDir.exists()) {
              await _deleteDirectoryContents(buildDir.path);
              try {
                await buildDir.delete(recursive: true);
              } catch (_) {}
            }

            // 3. Remove .dart_tool/build if present
            final dartToolBuild = Directory('$projDir/.dart_tool/build');
            if (await dartToolBuild.exists()) {
              try {
                await dartToolBuild.delete(recursive: true);
              } catch (_) {}
            }

            final remaining = await getPathSize('$projDir/build');
            final freed = (prevSize > remaining) ? (prevSize - remaining) : prevSize;
            totalFreed += freed;
          }

          return CleanResult(
            success: true,
            message: 'Cleaned ${projectsMap.length} Flutter projects. Reclaimed ${formatBytes(totalFreed)}.',
            freedBytes: totalFreed,
          );

        case 'xcode_derived_data':
          final path = _resolvePath(target.targetPath);
          await _deleteDirectoryContents(path);
          break;

        case 'xcode_caches':
          final path = _resolvePath(target.targetPath);
          await _deleteDirectoryContents(path);
          break;

        case 'simulator_unavailable':
          // 1. Delete unavailable simulators
          try {
            await Process.run('xcrun', ['simctl', 'delete', 'unavailable']);
          } catch (_) {}
          // 2. Clear CoreSimulator caches
          final cachesPath = _resolvePath(target.targetPath);
          await _deleteDirectoryContents(cachesPath);
          break;

        case 'flutter_pub_cache':
          // Run flutter pub cache clean --force
          var result = await Process.run('flutter', ['pub', 'cache', 'clean', '--force']);
          if (result.exitCode != 0) {
            // Fallback to fvm flutter
            result = await Process.run('fvm', ['flutter', 'pub', 'cache', 'clean', '--force']);
          }
          break;

        case 'android_gradle_cache':
          // Kill active gradle daemons first to unlock files
          try {
            await Process.run('pkill', ['-f', '.*GradleDaemon.*']);
          } catch (_) {}
          final cachesPath = _resolvePath(target.targetPath);
          await _deleteDirectoryContents(cachesPath);
          final daemonPath = _resolvePath('~/.gradle/daemon');
          await _deleteDirectoryContents(daemonPath);
          break;

        case 'android_ndk':
          final path = _resolvePath(target.targetPath);
          await _deleteDirectoryContents(path);
          break;

        case 'docker_system_prune':
          final res = await Process.run('docker', ['system', 'prune', '-f']);
          if (res.exitCode != 0) {
            return CleanResult(
              success: false,
              message: res.stderr.toString(),
            );
          }
          break;

        default:
          return const CleanResult(
            success: false,
            message: 'Unknown clean target.',
          );
      }

      // Re-scan size after cleaning
      final newSize = await getPathSize(target.targetPath);
      final freed = (initialSize > newSize) ? (initialSize - newSize) : initialSize;

      return CleanResult(
        success: true,
        message: 'Cleaned successfully! Reclaimed ${formatBytes(freed)}.',
        freedBytes: freed,
      );
    } catch (e) {
      return CleanResult(
        success: false,
        message: 'Clean error: ${e.toString()}',
      );
    }
  }

  /// Cleans build cache for a single Flutter project
  Future<CleanResult> cleanSingleProject(String projDir) async {
    try {
      final initialSize = await getPathSize('$projDir/build');

      // 1. Run flutter clean with timeout
      try {
        await Process.run(
          'flutter',
          ['clean'],
          workingDirectory: projDir,
          runInShell: true,
        ).timeout(const Duration(seconds: 15));
      } catch (_) {}

      // 2. Guarantee deletion of build directory if any leftovers remain
      final buildDir = Directory('$projDir/build');
      if (await buildDir.exists()) {
        await _deleteDirectoryContents(buildDir.path);
        try {
          await buildDir.delete(recursive: true);
        } catch (_) {}
      }

      // 3. Remove .dart_tool/build if present
      final dartToolBuild = Directory('$projDir/.dart_tool/build');
      if (await dartToolBuild.exists()) {
        try {
          await dartToolBuild.delete(recursive: true);
        } catch (_) {}
      }

      final remaining = await getPathSize('$projDir/build');
      final freed = (initialSize > remaining) ? (initialSize - remaining) : initialSize;

      return CleanResult(
        success: true,
        message: 'Cleaned project successfully! Reclaimed ${formatBytes(freed)}.',
        freedBytes: freed,
      );
    } catch (e) {
      return CleanResult(
        success: false,
        message: 'Clean error: ${e.toString()}',
      );
    }
  }

  /// Deletes all files and subdirectories within a directory, preserving the directory itself
  Future<void> _deleteDirectoryContents(String path) async {
    final dir = Directory(_resolvePath(path));
    if (!await dir.exists()) return;

    await for (final entity in dir.list(followLinks: false)) {
      try {
        if (entity is Directory) {
          await entity.delete(recursive: true);
        } else if (entity is File || entity is Link) {
          await entity.delete();
        }
      } catch (_) {
        // Continue cleaning other entities even if one fails
      }
    }
  }
}
