import 'dart:convert';

import 'package:app/data/garage_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('load result maps typed storage failures without exposing diagnostics', () async {
    final result = await GarageRepository(storage: _Storage(readError: true))
        .loadCollectionResult();

    expect(result, isA<GarageFailure<GarageCollection>>());
    final failure = result as GarageFailure<GarageCollection>;
    expect(failure.kind, GarageFailureKind.storage);
  });

  test('load result preserves corruption recovery as a successful empty state', () async {
    final result = await GarageRepository(storage: _Storage(payload: '{'))
        .loadCollectionResult();

    expect(result, isA<GarageSuccess<GarageCollection>>());
    expect((result as GarageSuccess<GarageCollection>).value.isEmpty, isTrue);
  });

  test('load result maps quarantine failure without exposing its exception', () async {
    final result = await GarageRepository(
      storage: _FailingQuarantineStorage(),
    ).loadCollectionResult();

    expect(result, isA<GarageFailure<GarageCollection>>());
    expect((result as GarageFailure<GarageCollection>).kind, GarageFailureKind.write);
  });

  test('save result maps validation and conflict failures', () async {
    final repository = GarageRepository(storage: _Storage());
    final invalid = GarageCollection(
      vehicles: const [],
      selectedVehicleId: 'missing',
      defaultVehicleId: GarageCollection.lastUsedVehicleId,
    );

    final validation = await repository.saveCollectionResult(invalid);
    expect(validation, isA<GarageFailure<void>>());
    expect((validation as GarageFailure<void>).kind, GarageFailureKind.validation);

    final valid = const GarageCollection(
      vehicles: [],
      selectedVehicleId: '',
      defaultVehicleId: GarageCollection.lastUsedVehicleId,
    );
    await repository.saveCollectionResult(valid);
    final conflict = await repository.saveCollectionResult(valid, expectedRevision: 0);
    expect(conflict, isA<GarageFailure<void>>());
    expect((conflict as GarageFailure<void>).kind, GarageFailureKind.conflict);
  });
}

class _Storage implements GarageStorage {
  _Storage({this.readError = false, this.payload});

  final bool readError;
  final String? payload;

  @override
  Future<String?> read() async {
    if (readError) throw StateError('offline');
    if (payload != null) return payload;
    return jsonEncode(const GarageCollection(
      vehicles: [],
      selectedVehicleId: '',
      defaultVehicleId: GarageCollection.lastUsedVehicleId,
    ).toJson());
  }

  @override
  Future<bool> write(String value) async => true;
}

class _FailingQuarantineStorage
    implements GarageStorage, GarageQuarantineStorage {
  @override
  Future<String?> read() async => '{';

  @override
  Future<bool> write(String value) async => true;

  @override
  Future<void> quarantine(String rawPayload) async {
    throw StateError('private storage diagnostic');
  }
}
