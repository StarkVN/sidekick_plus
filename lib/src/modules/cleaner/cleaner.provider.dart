import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/clean_target.dart';
import 'services/cleaner.service.dart';

/// State of the cleaner module
@immutable
class CleanerState {
  /// All clean targets
  final List<CleanTarget> targets;

  /// Whether a full scan is currently in progress
  final bool isScanningAll;

  /// Whether any target is currently being cleaned
  final bool isCleaningAny;

  /// Total bytes freed during the current session
  final int totalFreedBytes;

  /// Constructor
  const CleanerState({
    required this.targets,
    this.isScanningAll = false,
    this.isCleaningAny = false,
    this.totalFreedBytes = 0,
  });

  /// Total reclaimable bytes across all available targets
  int get totalReclaimableBytes {
    var total = 0;
    for (final t in targets) {
      if (t.isAvailable && t.sizeInBytes != null) {
        total += t.sizeInBytes!;
      }
    }
    return total;
  }

  /// Total reclaimable bytes for safe-only targets
  int get totalSafeReclaimableBytes {
    var total = 0;
    for (final t in targets) {
      if (t.isAvailable && !t.isDangerous && t.sizeInBytes != null) {
        total += t.sizeInBytes!;
      }
    }
    return total;
  }

  /// Copy with
  CleanerState copyWith({
    List<CleanTarget>? targets,
    bool? isScanningAll,
    bool? isCleaningAny,
    int? totalFreedBytes,
  }) {
    return CleanerState(
      targets: targets ?? this.targets,
      isScanningAll: isScanningAll ?? this.isScanningAll,
      isCleaningAny: isCleaningAny ?? this.isCleaningAny,
      totalFreedBytes: totalFreedBytes ?? this.totalFreedBytes,
    );
  }
}

/// State notifier for Cleaner with persistent caching
class CleanerNotifier extends StateNotifier<CleanerState> {
  final CleanerService _service = CleanerService.instance;

  /// Constructor
  CleanerNotifier()
      : super(CleanerState(targets: CleanerService.instance.getInitialTargets())) {
    _initAndScan();
  }

  Future<void> _initAndScan() async {
    await _loadFromCache();
    // Non-blocking background verification that only updates if directory modified timestamp changed
    await scanAll(force: false);
  }

  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final updated = state.targets.map((t) {
        final cachedSize = prefs.getInt('cleaner_cache_${t.id}_size');
        final cachedMod = prefs.getInt('cleaner_cache_${t.id}_mod');
        if (cachedSize != null) {
          return t.copyWith(
            sizeInBytes: cachedSize,
            lastModifiedTimestamp: cachedMod,
          );
        }
        return t;
      }).toList();
      state = state.copyWith(targets: updated);
    } catch (_) {}
  }

  Future<void> _saveTargetToCache(CleanTarget target) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (target.sizeInBytes != null) {
        await prefs.setInt('cleaner_cache_${target.id}_size', target.sizeInBytes!);
      }
      if (target.lastModifiedTimestamp != null) {
        await prefs.setInt('cleaner_cache_${target.id}_mod', target.lastModifiedTimestamp!);
      }
    } catch (_) {}
  }

  /// Scans targets with optional force flag
  Future<void> scanAll({bool force = true}) async {
    state = state.copyWith(
      isScanningAll: true,
      targets: state.targets.map((t) {
        // If force is true or size is not cached yet, mark calculating
        if (force || t.sizeInBytes == null) {
          return t.copyWith(isCalculating: true);
        }
        return t;
      }).toList(),
    );

    final updatedTargets = <CleanTarget>[];
    for (final target in state.targets) {
      try {
        final scanned = await _service.scanTarget(target, force: force);
        updatedTargets.add(scanned);
        await _saveTargetToCache(scanned);

        state = state.copyWith(
          targets: state.targets.map((t) => t.id == target.id ? scanned : t).toList(),
        );
      } catch (e) {
        updatedTargets.add(target.copyWith(isCalculating: false, error: e.toString()));
      }
    }

    state = state.copyWith(
      isScanningAll: false,
      targets: updatedTargets,
    );
  }

  /// Cleans a specific target by ID
  Future<CleanResult> cleanTarget(String targetId) async {
    final index = state.targets.indexWhere((t) => t.id == targetId);
    if (index == -1) {
      return const CleanResult(success: false, message: 'Target not found');
    }

    final target = state.targets[index];
    state = state.copyWith(
      isCleaningAny: true,
      targets: state.targets
          .map((t) => t.id == targetId
              ? t.copyWith(isCleaning: true, error: null)
              : t)
          .toList(),
    );

    final result = await _service.cleanTarget(target);
    final scannedTarget = await _service.scanTarget(target, force: true);
    await _saveTargetToCache(scannedTarget);

    state = state.copyWith(
      isCleaningAny: state.targets.any((t) => t.id != targetId && t.isCleaning),
      totalFreedBytes: state.totalFreedBytes + result.freedBytes,
      targets: state.targets
          .map((t) => t.id == targetId
              ? scannedTarget.copyWith(
                  isCleaning: false,
                  isCleaned: result.success,
                  error: result.success ? null : result.message,
                )
              : t)
          .toList(),
    );

    return result;
  }

  /// Cleans all safe targets that have size > 0
  Future<List<CleanResult>> cleanAllSafe() async {
    final safeTargets = state.targets.where((t) =>
        t.isAvailable && !t.isDangerous && (t.sizeInBytes ?? 0) > 0).toList();

    final results = <CleanResult>[];
    for (final target in safeTargets) {
      final res = await cleanTarget(target.id);
      results.add(res);
    }
    return results;
  }
}

/// Global provider for Cleaner state
final cleanerProvider = StateNotifierProvider<CleanerNotifier, CleanerState>((ref) {
  return CleanerNotifier();
});
