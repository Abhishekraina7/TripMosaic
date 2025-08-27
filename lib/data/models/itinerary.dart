import 'package:isar/isar.dart';
part 'itinerary.g.dart';

@Collection()
class Itinerary {
  Id id = Isar.autoIncrement;
  late String title;
  late List<ItineraryDay> days;
}

@embedded
class ItineraryDay {
  late String date;
  late String summary;
  late List<ItineraryItem> items;
}

@embedded
class ItineraryItem {
  late String time;
  late String activity;
  late double lat;
  late double lng;
}
