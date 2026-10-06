import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/service_history_entry.dart';
import '../models/service_item.dart';
import '../models/tire_item.dart';

class GarageSnapshot {
  const GarageSnapshot({
    required this.odometer,
    required this.services,
    required this.tires,
    required this.history,
  });
  final int odometer;
  final List<ServiceItem> services;
  final List<TireItem> tires;
  final List<ServiceHistoryEntry> history;
  Map<String, dynamic> toJson() => {
    'schemaVersion': 2,
    'odometer': odometer,
    'services': services.map((item) => item.toJson()).toList(),
    'tires': tires.map((item) => item.toJson()).toList(),
    'history': history.map((entry) => entry.toJson()).toList(),
  };
  factory GarageSnapshot.fromJson(Map<String, dynamic> json) {
    final odometer = json['odometer'] as int;
    return GarageSnapshot(
      odometer: odometer,
      services: (json['services'] as List)
          .cast<Map>()
          .map((item) => ServiceItem.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
      tires:
          (json['tires'] as List?)
              ?.cast<Map>()
              .map((item) => TireItem.fromJson(Map<String, dynamic>.from(item)))
              .toList() ??
          TireItem.defaultsForOdometer(odometer),
      history: (json['history'] as List? ?? [])
          .cast<Map>()
          .map(
            (entry) =>
                ServiceHistoryEntry.fromJson(Map<String, dynamic>.from(entry)),
          )
          .toList(),
    );
  }
}

class GarageRepository {
  static const _key = 'garage_snapshot_v1';
  Future<GarageSnapshot?> load() async {
    final raw = (await SharedPreferences.getInstance()).getString(_key);
    return raw == null
        ? null
        : GarageSnapshot.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> save(GarageSnapshot snapshot) async =>
      (await SharedPreferences.getInstance()).setString(
        _key,
        jsonEncode(snapshot.toJson()),
      );
}
