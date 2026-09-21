import 'package:flutter/material.dart';
import '../../common/utils/helpers.dart';

/// Categories for cleanable targets
enum CleanCategory {
  /// Xcode and iOS Simulator
  xcode,

  /// Flutter framework & build artifacts
  flutter,

  /// Android SDK & Gradle
  android,

  /// Docker containers and caches
  docker,
}

/// Result of a clean operation
class CleanResult {
  /// Whether the clean was successful
  final bool success;

  /// Output message or error description
  final String message;

  /// Amount of bytes freed in this clean
  final int freedBytes;

  /// Constructor
  const CleanResult({
    required this.success,
    required this.message,
    this.freedBytes = 0,
  });
}

/// A target that can be scanned and cleaned
@immutable
class CleanTarget {
  /// Unique identifier
  final String id;

  /// i18n key for title
  final String titleKey;

  /// i18n key for subtitle
  final String subtitleKey;

  /// Category
  final CleanCategory category;

  /// Resolved physical path on disk
  final String targetPath;

  /// Shell command preview
  final String commandPreview;

  /// i18n key for description
  final String descriptionKey;

  /// Size in bytes currently occupied (null if not yet scanned)
  final int? sizeInBytes;

  /// Timestamp of the last directory modification when scanned
  final int? lastModifiedTimestamp;

  /// Whether size calculation is currently running
  final bool isCalculating;

  /// Whether cleaning is in progress
  final bool isCleaning;

  /// Whether this target was just cleaned in the current session
  final bool isCleaned;

  /// Whether this clean action is dangerous and requires warning confirmation
  final bool isDangerous;

  /// Whether this target is available on the machine (e.g. tool installed / directory exists)
  final bool isAvailable;

  /// Last error message if any
  final String? error;

  /// Constructor
  const CleanTarget({
    required this.id,
    required this.titleKey,
    required this.subtitleKey,
    required this.category,
    required this.targetPath,
    required this.commandPreview,
    required this.descriptionKey,
    this.sizeInBytes,
    this.lastModifiedTimestamp,
    this.isCalculating = false,
    this.isCleaning = false,
    this.isCleaned = false,
    this.isDangerous = false,
    this.isAvailable = true,
    this.error,
  });

  /// Get localized title
  String getTitle(BuildContext context) => context.i18n(titleKey);

  /// Get localized subtitle
  String getSubtitle(BuildContext context) => context.i18n(subtitleKey);

  /// Get localized description
  String getDescription(BuildContext context) => context.i18n(descriptionKey);

  /// Copy with
  CleanTarget copyWith({
    String? id,
    String? titleKey,
    String? subtitleKey,
    CleanCategory? category,
    String? targetPath,
    String? commandPreview,
    String? descriptionKey,
    int? sizeInBytes,
    int? lastModifiedTimestamp,
    bool? isCalculating,
    bool? isCleaning,
    bool? isCleaned,
    bool? isDangerous,
    bool? isAvailable,
    String? error,
  }) {
    return CleanTarget(
      id: id ?? this.id,
      titleKey: titleKey ?? this.titleKey,
      subtitleKey: subtitleKey ?? this.subtitleKey,
      category: category ?? this.category,
      targetPath: targetPath ?? this.targetPath,
      commandPreview: commandPreview ?? this.commandPreview,
      descriptionKey: descriptionKey ?? this.descriptionKey,
      sizeInBytes: sizeInBytes ?? this.sizeInBytes,
      lastModifiedTimestamp: lastModifiedTimestamp ?? this.lastModifiedTimestamp,
      isCalculating: isCalculating ?? this.isCalculating,
      isCleaning: isCleaning ?? this.isCleaning,
      isCleaned: isCleaned ?? this.isCleaned,
      isDangerous: isDangerous ?? this.isDangerous,
      isAvailable: isAvailable ?? this.isAvailable,
      error: error,
    );
  }
}
