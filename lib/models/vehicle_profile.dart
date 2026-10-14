import 'dart:math';

import '../data/garage_repository.dart';
import '../models/service_history_entry.dart';

class VehicleProfile {
  const VehicleProfile({
    required this.id,
    required this.year,
    this.make,
    required this.model,
    required this.garage,
  });

  final String id;
  final int year;
  final String? make;
  final String model;
  final GarageSnapshot garage;

  String get name => '${year.toString()} ${[
    if (make?.trim().isNotEmpty ?? false) make!.trim(),
    model.trim(),
  ].join(' ')}';

  VehicleProfile copyWith({
    int? year,
    Object? make = _unset,
    String? model,
    GarageSnapshot? garage,
  }) => VehicleProfile(
    id: id,
    year: year ?? this.year,
    make: make == _unset ? this.make : make as String?,
    model: model ?? this.model,
    garage: garage ?? this.garage,
  );

  static const _unset = Object();

  /// Returns this profile with a new odometer while preserving garage data.
  VehicleProfile withOdometer(int odometer) => copyWith(
    garage: GarageSnapshot(
      odometer: odometer,
      services: garage.services,
      tires: garage.tires,
      history: garage.history,
      lastUpdatedAt: garage.lastUpdatedAt,
    ),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'year': year,
    if (make?.trim().isNotEmpty ?? false) 'make': make,
    'model': model,
    'garage': garage.toJson(),
  };

  factory VehicleProfile.fromJson(Map<String, dynamic> json) => VehicleProfile(
    id: json['id'] as String,
    year: json['year'] as int,
    make: json['make'] as String?,
    model: json['model'] as String,
    garage: GarageSnapshot.fromJson(
      Map<String, dynamic>.from(json['garage'] as Map),
    ),
  );

  static VehicleProfile clean({
    required int year,
    String? make,
    required String model,
    required int odometer,
  }) => VehicleProfile(
    id: _newId(),
    year: year,
    make: make?.trim().isEmpty ?? true ? null : make!.trim(),
    model: model.trim(),
    garage: GarageSnapshot(
      odometer: odometer,
      services: const [],
      tires: const [],
      history: const <ServiceHistoryEntry>[],
    ),
  );

  static String _newId() {
    final random = Random.secure();
    return List.generate(16, (_) => random.nextInt(256))
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join();
  }
}
