import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../models/itinerary.dart';

class IsarRepository {
  static IsarRepository? _instance;
  Isar? _isar;

  IsarRepository._internal();

  static IsarRepository getInstance() {
    _instance ??= IsarRepository._internal();
    return _instance!;
  }

  Future<void> initialize() async {
    if (_isar != null) return;
    final dir = await getApplicationDocumentsDirectory();
    _isar = await Isar.open(
      [ItinerarySchema],
      directory: dir.path,
    );
  }

  Future<void> saveItinerary(Itinerary itinerary) async {
    await initialize();
    await _isar!.writeTxn(() async {
      await _isar!.itinerarys.put(itinerary);
    });
  }

  Future<List<Itinerary>> getAllItineraries() async {
    await initialize();
    return await _isar!.itinerarys.where().findAll();
  }

  Future<void> deleteItinerary(int id) async {
    await initialize();
    await _isar!.writeTxn(() async {
      await _isar!.itinerarys.delete(id);
    });
  }

  Future<void> clearAllItineraries() async {
    await initialize();
    await _isar!.writeTxn(() async {
      await _isar!.itinerarys.clear();
    });
    print('All saved trips cleared!');
  }
}

// Legacy functions for backward compatibility
Future<Isar> openIsarInstance() async {
  final dir = await getApplicationDocumentsDirectory();
  return await Isar.open(
    [ItinerarySchema],
    directory: dir.path,
  );
}

Future<void> saveItinerary(Itinerary itinerary) async {
  final isar = await openIsarInstance();
  await isar.writeTxn(() async {
    await isar.itinerarys.put(itinerary);
  });
}
