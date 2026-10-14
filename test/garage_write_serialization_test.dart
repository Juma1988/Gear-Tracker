import 'dart:async';
import 'dart:convert';

import 'package:app/data/garage_repository.dart';
import 'package:app/models/vehicle_profile.dart';
import 'package:flutter_test/flutter_test.dart';

GarageCollection _collection({int odometer = 100}) => GarageCollection(
  vehicles: [
    VehicleProfile(
      id: 'v1',
      year: 2020,
      make: 'Toyota',
      model: 'Corolla',
      garage: GarageSnapshot(
        odometer: odometer,
        services: const [],
        tires: const [],
        history: const [],
      ),
    ),
  ],
  selectedVehicleId: 'v1',
  defaultVehicleId: GarageCollection.lastUsedVehicleId,
);

int _odometerOf(String payload) {
  final json = jsonDecode(payload) as Map<String, dynamic>;
  final vehicles = json['vehicles'] as List<dynamic>;
  final vehicle = vehicles.single as Map<String, dynamic>;
  return (vehicle['garage'] as Map<String, dynamic>)['odometer'] as int;
}

void main() {
  test('overlapping saves are serialized in call order', () async {
    final storage = _DelayedStorage();
    final repository = GarageRepository(storage: storage);

    final first = repository.saveCollection(_collection(odometer: 1));
    final second = repository.saveCollection(_collection(odometer: 2));

    await Future<void>.delayed(Duration.zero);
    expect(
      storage.pending,
      hasLength(1),
      reason: 'the second save must wait for the first to finish',
    );

    storage.pending[0].complete(true);
    await first;
    await Future<void>.delayed(Duration.zero);
    expect(storage.pending, hasLength(2));

    storage.pending[1].complete(true);
    await second;

    expect(storage.writes, hasLength(2));
    expect(_odometerOf(storage.writes[0]), 1);
    expect(_odometerOf(storage.writes[1]), 2);
    expect(repository.revision, 2);
  });

  test('a failed save surfaces to its caller without blocking the queue', () async {
    final storage = _DelayedStorage();
    final repository = GarageRepository(storage: storage);

    final failing = repository.saveCollection(_collection(odometer: 1));
    final following = repository.saveCollection(_collection(odometer: 2));

    await Future<void>.delayed(Duration.zero);
    storage.pending[0].complete(false);
    await expectLater(
      failing,
      throwsA(
        isA<GarageDataException>().having(
          (e) => e.kind,
          'kind',
          GarageFailureKind.write,
        ),
      ),
    );

    await Future<void>.delayed(Duration.zero);
    expect(
      storage.pending,
      hasLength(2),
      reason: 'a failed save must not strand the next one',
    );
    storage.pending[1].complete(true);
    await following;

    expect(_odometerOf(storage.writes.single), 2);
    expect(repository.revision, 1);
  });

  test('the revision guard rejects a stale snapshot and writes nothing', () async {
    final storage = _ImmediateStorage();
    final repository = GarageRepository(storage: storage);

    await repository.saveCollection(_collection(odometer: 5));
    expect(repository.revision, 1);

    await expectLater(
      repository.saveCollection(_collection(odometer: 9), expectedRevision: 0),
      throwsA(
        isA<GarageConflictException>()
            .having((e) => e.kind, 'kind', GarageFailureKind.conflict)
            .having((e) => e.expectedRevision, 'expected', 0)
            .having((e) => e.actualRevision, 'actual', 1),
      ),
    );

    expect(storage.writes, hasLength(1));
    expect(repository.revision, 1);
    expect(_odometerOf(storage.writes.single), 5);
  });

  test('the revision guard accepts a matching revision', () async {
    final storage = _ImmediateStorage();
    final repository = GarageRepository(storage: storage);

    await repository.saveCollection(_collection(odometer: 5));
    await repository.saveCollection(
      _collection(odometer: 6),
      expectedRevision: repository.revision,
    );

    expect(storage.writes, hasLength(2));
    expect(repository.revision, 2);
    expect(_odometerOf(storage.writes.last), 6);
  });

  test('a queued stale snapshot is checked after earlier writes finish', () async {
    final storage = _DelayedStorage();
    final repository = GarageRepository(storage: storage);

    final first = repository.saveCollection(_collection(odometer: 5));
    final stale = repository.saveCollection(
      _collection(odometer: 9),
      expectedRevision: 0,
    );

    await Future<void>.delayed(Duration.zero);
    storage.pending.single.complete(true);
    await first;

    await expectLater(stale, throwsA(isA<GarageConflictException>()));
    expect(storage.writes, hasLength(1));
    expect(repository.revision, 1);
  });

  test('a conflict does not poison later queued saves', () async {
    final storage = _DelayedStorage();
    final repository = GarageRepository(storage: storage);

    final first = repository.saveCollection(_collection(odometer: 1));
    final stale = repository.saveCollection(
      _collection(odometer: 2),
      expectedRevision: 0,
    );
    final following = repository.saveCollection(
      _collection(odometer: 3),
      expectedRevision: 1,
    );

    await Future<void>.delayed(Duration.zero);
    storage.pending.single.complete(true);
    await first;
    await expectLater(stale, throwsA(isA<GarageConflictException>()));

    await Future<void>.delayed(Duration.zero);
    expect(storage.pending, hasLength(2));
    storage.pending[1].complete(true);
    await following;

    expect(storage.writes, hasLength(2));
    expect(_odometerOf(storage.writes.last), 3);
    expect(repository.revision, 2);
  });

  test('the latest queued write is readable by a new repository instance', () async {
    final storage = _ImmediateStorage();
    final repository = GarageRepository(storage: storage);

    final first = repository.saveCollection(_collection(odometer: 7));
    final second = repository.saveCollection(_collection(odometer: 8));
    await Future.wait([first, second]);

    final restartedRepository = GarageRepository(storage: storage);
    final restored = await restartedRepository.loadCollection();

    expect(restored.selectedVehicle.garage.odometer, 8);
  });
}

class _DelayedStorage implements GarageStorage {
  final List<Completer<bool>> pending = [];
  final List<String> writes = [];
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<bool> write(String value) {
    final completer = Completer<bool>();
    pending.add(completer);
    return completer.future.then((ok) {
      if (ok) {
        this.value = value;
        writes.add(value);
      }
      return ok;
    });
  }
}

class _ImmediateStorage implements GarageStorage {
  final List<String> writes = [];
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<bool> write(String value) async {
    this.value = value;
    writes.add(value);
    return true;
  }
}
