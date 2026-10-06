import '../models/service_item.dart';
import '../models/tire_item.dart';

const initialOdometer = '074850';

final initialServices = [
  ServiceItem(
    id: 'engine-oil',
    name: 'Engine Oil',
    note: '5W-40 SYN',
    serviceOdometer: 74850,
    intervalKm: 10000,
    iconKey: 'oil',
    installDate: DateTime(2026, 10, 6),
  ),
];

final initialTires = TireItem.defaultsForOdometer(int.parse(initialOdometer));
