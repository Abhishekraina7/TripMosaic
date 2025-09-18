import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/datasources/gemini_api.dart';
import '../../data/models/itinerary.dart';
import '../../data/repositories/isar_repository.dart';

class TripEditScreen extends StatefulWidget {
  final Itinerary trip;
  final IsarRepository? repository;

  const TripEditScreen({
    Key? key,
    required this.trip,
    this.repository,
  }) : super(key: key);

  @override
  State<TripEditScreen> createState() => _TripEditScreenState();
}

class _TripEditScreenState extends State<TripEditScreen> {
  final TextEditingController _editController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late IsarRepository _repository;
  late Itinerary _currentTrip;
  bool _isModifying = false;
  final List<ChatMessage> _editMessages = [];

  @override
  void initState() {
    super.initState();
    _currentTrip = widget.trip;
    _initializeRepository();
  }

  @override
  void dispose() {
    _editController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeRepository() async {
    if (widget.repository != null) {
      _repository = widget.repository!;
    } else {
      _repository = IsarRepository.getInstance();
      await _repository.initialize();
    }
  }

  //FIX: Helper function to convert pseudo-JSON into valid JSON
  String _fixPseudoJson(String input) {
    // Adds quotes around keys: title: -> "title":
    String fixed = input.replaceAllMapped(RegExp(r'(\w+)\s*:'), (m) => '"${m[1]}":');
    return fixed;
  }

  // FIX: Function to safely parse the trip
  Itinerary _parseTrip(dynamic tripData) {
    if (tripData is Itinerary) return tripData;
    try {
      if (tripData is String) {
        final fixedJson = _fixPseudoJson(tripData);
        final decoded = jsonDecode(fixedJson);
        return Itinerary.fromJson(decoded);
      } else if (tripData is Map<String, dynamic>) {
        return Itinerary.fromJson(tripData);
      }
    } catch (e) {
      debugPrint("Trip parsing failed: $e");
    }
    return widget.trip; // fallback
  }

  @override
  Widget build(BuildContext context) {
    // 🆕 FIX: Always re-parse trip to avoid platform-specific issues
    _currentTrip = _parseTrip(_currentTrip);

    return Scaffold(
      appBar: AppBar(title: const Text('Trip Chat')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: _currentTrip.days.length,
              itemBuilder: (context, index) {
                final day = _currentTrip.days[index];
                return Card(
                  margin: const EdgeInsets.all(8),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(day.date, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        if (day.summary != null) Text(day.summary!),
                        ...day.items.map((item) => ListTile(
                              leading: Text(item.time),
                              title: Text(item.activity),
                              trailing: IconButton(
                                icon: const Icon(Icons.map),
                                onPressed: () async {
                                  final url = _generateMapUrl('${item.lat},${item.lng}', activity: item.activity);
                                  if (await canLaunchUrl(Uri.parse(url))) {
                                    await launchUrl(Uri.parse(url));
                                  }
                                },
                              ),
                            )),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _generateMapUrl(String location, {String? activity}) {
    if (location.isEmpty || location == '0,0') {
      return 'https://www.google.com/maps/';
    }

    final coords = location.split(',');
    if (coords.length == 2) {
      double lat = double.tryParse(coords[0].trim()) ?? 0.0;
      double lng = double.tryParse(coords[1].trim()) ?? 0.0;

      String searchTerm = 'places+near+this+location';
      if (activity != null && activity.isNotEmpty) {
        searchTerm = Uri.encodeComponent(activity);
      }

      return 'https://www.google.com/maps/search/$searchTerm/@$lat,$lng,11z';
    }

    final encodedLocation = Uri.encodeComponent(location);
    return 'https://www.google.com/maps/search/$encodedLocation';
  }
}
