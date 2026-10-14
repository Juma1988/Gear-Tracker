import 'dart:convert';

import 'garage_repository.dart';

/// Envelope identity for the versioned gear backup.
abstract final class GarageBackupFormat {
  /// Marks a payload as a GearTracker garage backup.
  static const String id = 'geartracker.garage';

  /// Current envelope version. Bump only for incompatible envelope changes.
  static const int currentVersion = 1;
}

/// Why an imported backup string was rejected.
///
/// These values are deliberately coarse: they drive localized recovery copy and
/// must never leak a raw parser exception to the user.
enum GarageBackupFailure {
  empty,
  malformed,
  wrongFormat,
  unsupportedVersion,
  invalidData,
}

/// Raised when a backup cannot be produced or accepted.
class GarageBackupException extends FormatException {
  GarageBackupException(this.failure, String message, {this.cause})
    : super(message);

  final GarageBackupFailure failure;

  /// Underlying cause, kept for diagnostics only — never shown to the user.
  final Object? cause;
}

/// Encodes and decodes the versioned garage backup envelope.
///
/// The envelope wraps [GarageCollection] so the *backup format* can evolve
/// independently of the *persisted collection schema*:
///
/// ```json
/// {
///   "format": "geartracker.garage",
///   "formatVersion": 1,
///   "exportedAt": "2026-10-11T17:20:00.000Z",
///   "garage": { "schemaVersion": 2, "vehicles": [ … ] }
/// }
/// ```
///
/// Decoding fully validates the imported collection before returning, so a
/// caller can never apply a payload the loader would later reject.
class GarageBackupCodec {
  const GarageBackupCodec();

  String encode(GarageCollection collection, {DateTime? exportedAt}) {
    final envelope = <String, dynamic>{
      'format': GarageBackupFormat.id,
      'formatVersion': GarageBackupFormat.currentVersion,
      if (exportedAt != null) 'exportedAt': exportedAt.toUtc().toIso8601String(),
      'garage': collection.toJson(),
    };
    return const JsonEncoder.withIndent('  ').convert(envelope);
  }

  GarageCollection decode(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      throw GarageBackupException(
        GarageBackupFailure.empty,
        'Backup text was empty',
      );
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(trimmed);
    } catch (error) {
      throw GarageBackupException(
        GarageBackupFailure.malformed,
        'Backup is not valid JSON',
        cause: error,
      );
    }
    if (decoded is! Map) {
      throw GarageBackupException(
        GarageBackupFailure.malformed,
        'Backup is not an object',
      );
    }

    final envelope = Map<String, dynamic>.from(decoded);
    if (envelope['format'] != GarageBackupFormat.id) {
      throw GarageBackupException(
        GarageBackupFailure.wrongFormat,
        'Payload is not a GearTracker backup',
      );
    }

    final version = envelope['formatVersion'];
    if (version is! int ||
        version < 1 ||
        version > GarageBackupFormat.currentVersion) {
      throw GarageBackupException(
        GarageBackupFailure.unsupportedVersion,
        'Backup version is not supported',
      );
    }

    final exportedAt = envelope['exportedAt'];
    if (exportedAt != null) {
      if (exportedAt is! String) {
        throw GarageBackupException(
          GarageBackupFailure.invalidData,
          'Backup export time is invalid',
        );
      }
      try {
        DateTime.parse(exportedAt);
      } on FormatException catch (error) {
        throw GarageBackupException(
          GarageBackupFailure.invalidData,
          'Backup export time is invalid',
          cause: error,
        );
      }
    }

    final garage = envelope['garage'];
    if (garage is! Map) {
      throw GarageBackupException(
        GarageBackupFailure.invalidData,
        'Backup contains no garage data',
      );
    }

    try {
      // Backups may contain a supported historical collection schema and
      // historical nested snapshots. Migrate the complete tree before the
      // strict collection validation/write boundary.
      return GarageCollection.migrate(Map<String, dynamic>.from(garage));
    } on GarageBackupException {
      rethrow;
    } on FormatException catch (error) {
      throw GarageBackupException(
        GarageBackupFailure.invalidData,
        error.message,
        cause: error,
      );
    } catch (error) {
      throw GarageBackupException(
        GarageBackupFailure.invalidData,
        'Backup data was rejected',
        cause: error,
      );
    }
  }
}
