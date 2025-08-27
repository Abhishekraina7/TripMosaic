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

  // Helper function to clean coordinates from location text
  String _cleanLocationText(String location) {
    if (location.isEmpty) return location;
    
    // Remove coordinate patterns like (latitude,longitude) or latitude,longitude
    location = location.replaceAll(RegExp(r'\(\s*-?\d+\.?\d*\s*,\s*-?\d+\.?\d*\s*\)'), '');
    location = location.replaceAll(RegExp(r'\b-?\d+\.?\d+\s*,\s*-?\d+\.?\d+\b'), '');
    
    // Clean up extra whitespace and trim
    location = location.replaceAll(RegExp(r'\s+'), ' ').trim();
    
    // Remove leading/trailing commas or whitespace
    location = location.replaceAll(RegExp(r'^[,\s]+|[,\s]+$'), '');
    
    return location;
  }

  String _generateMapUrl(String location, {String? activity}) {
    if (location.isEmpty || location == '0,0') {
      return 'https://www.google.com/maps/';
    }
    
    final coords = location.split(',');
    if (coords.length == 2) {
      double lat = double.tryParse(coords[0].trim()) ?? 0.0;
      double lng = double.tryParse(coords[1].trim()) ?? 0.0;
      
      // Extract search term from activity if provided
      String searchTerm = 'places+near+this+location';
      if (activity != null && activity.isNotEmpty) {
        searchTerm = _extractSearchTerm(activity);
      }
      
      // Use the specific Google Maps URL format with dynamic search parameters
      return 'https://www.google.com/maps/search/$searchTerm/@$lat,$lng,11z/data=!4m3!1m2!2m1!1s$searchTerm?entry=ttu&g_ep=EgoyMDI1MDgxOS4wIKXMDSoASAFQAw%3D%3D';
    }
    
    final encodedLocation = Uri.encodeComponent(location);
    return 'https://www.google.com/maps/search/$encodedLocation?entry=ttu&g_ep=EgoyMDI1MDgxOS4wIKXMDSoASAFQAw%3D%3D';
  }

  String _extractSearchTerm(String activity) {
    final activityLower = activity.toLowerCase();
    
    // Check if activity contains specific place names (capitalized words)
    final words = activity.split(RegExp(r'[\s,.-]+'));
    final properNouns = <String>[];
    
    for (final word in words) {
      if (word.length > 2 && 
          word[0].toUpperCase() == word[0] && 
          !['Visit', 'Explore', 'Go', 'See', 'At', 'To', 'The', 'A', 'An', 'And', 'Or', 'Of', 'In', 'On'].contains(word)) {
        properNouns.add(word.toLowerCase());
      }
    }
    
    // If we found specific place names, use them for exact search
    if (properNouns.isNotEmpty) {
      return properNouns.join('+');
    }
    
    // Otherwise, check for generic place types and use "type near this location"
    final placeTypes = {
      'temple': 'temples+near+this+location',
      'restaurant': 'restaurants+near+this+location',
      'cafe': 'cafes+near+this+location',
      'museum': 'museums+near+this+location',
      'park': 'parks+near+this+location',
      'hotel': 'hotels+near+this+location',
      'mall': 'malls+near+this+location',
      'market': 'markets+near+this+location',
      'hospital': 'hospitals+near+this+location',
      'beach': 'beaches+near+this+location',
      'church': 'churches+near+this+location',
      'mosque': 'mosques+near+this+location',
      'school': 'schools+near+this+location',
      'cinema': 'cinemas+near+this+location',
      'gym': 'gyms+near+this+location',
    };
    
    for (final entry in placeTypes.entries) {
      if (activityLower.contains(entry.key)) {
        return entry.value;
      }
    }
    
    // Default fallback
    return 'places+near+this+location';
  }

  Future<void> _modifyTrip() async {
    final editCommand = _editController.text.trim();
    if (editCommand.isEmpty) return;

    setState(() {
      _isModifying = true;
      _editMessages.add(ChatMessage(
        text: editCommand,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _editController.clear();
    });

    _scrollToBottom();

    try {
      final apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
      if (apiKey.isEmpty) {
        throw Exception('Gemini API key not found. Please check your .env file.');
      }

      // Create a modification prompt that includes the current trip data
      final currentTripJson = _convertTripToJson(_currentTrip);
      final modificationPrompt = '''
I have this existing trip itinerary:
$currentTripJson

User wants to modify it with this request: "$editCommand"

Please return a new updated itinerary in the same JSON format, incorporating the user's changes while keeping the overall structure intact.
''';

      final newItineraryData = await fetchItineraryFromGemini(modificationPrompt, apiKey);
      
      setState(() {
        _editMessages.add(ChatMessage(
          text: "I've created a new version of your trip based on your request!",
          isUser: false,
          timestamp: DateTime.now(),
          itinerary: newItineraryData,
        ));
        _isModifying = false;
      });

      _scrollToBottom();
    } catch (e) {
      setState(() {
        _editMessages.add(ChatMessage(
          text: "Sorry, I encountered an error while creating the new trip: ${e.toString()}. Please try again.",
          isUser: false,
          timestamp: DateTime.now(),
        ));
        _isModifying = false;
      });
    }
  }

  String _convertTripToJson(Itinerary trip) {
    final tripData = {
      "title": trip.title,
      "startDate": trip.startDate,
      "endDate": trip.endDate,
      "days": trip.days.map((day) => {
        "date": day.date,
        "summary": day.summary,
        "items": day.items.map((item) => {
          "time": item.time,
          "activity": item.activity,
          "lat": item.lat,
          "lng": item.lng,
        }).toList(),
      }).toList(),
    };
    return tripData.toString();
  }

  Itinerary _convertJsonToTrip(Map<String, dynamic> jsonData) {
    final days = (jsonData['days'] as List).map((dayData) {
      final day = ItineraryDay();
      day.date = dayData['date'] ?? '';
      day.summary = dayData['summary'] ?? '';
      day.items = (dayData['items'] as List).map((itemData) {
        final item = ItineraryItem();
        item.time = itemData['time'] ?? '';
        item.activity = itemData['activity'] ?? '';
        item.lat = (itemData['lat'] as num?)?.toDouble() ?? 0.0;
        item.lng = (itemData['lng'] as num?)?.toDouble() ?? 0.0;
        return item;
      }).toList();
      return day;
    }).toList();

    return Itinerary()
      ..title = jsonData['title'] ?? 'Untitled Trip'
      ..startDate = jsonData['startDate'] ?? ''
      ..endDate = jsonData['endDate'] ?? ''
      ..days = days;
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF6FB),
      appBar: AppBar(
        title: const Text(
          'Edit Trip',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: () {
              Navigator.pop(context, _currentTrip);
            },
            tooltip: 'Save & Exit',
          ),
        ],
      ),
      body: Column(
        children: [
          // Current Trip Display
          Expanded(
            flex: 2,
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.edit_location, color: Colors.blue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _currentTrip.title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _currentTrip.days.length,
                      itemBuilder: (context, dayIndex) {
                        final day = _currentTrip.days[dayIndex];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  day.date,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.blue,
                                  ),
                                ),
                                if (day.summary.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    day.summary,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 8),
                                ...day.items.map((item) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 50,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          item.time,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.activity,
                                              style: const TextStyle(fontSize: 14),
                                            ),
                                            if (item.lat != 0.0 && item.lng != 0.0) ...[
                                              const SizedBox(height: 4),
                                              InkWell(
                                                onTap: () async {
                                                  final url = 'https://www.google.com/maps/@${item.lat},${item.lng},15z/data=!3m1!4b1?entry=ttu';
                                                  if (await canLaunchUrl(Uri.parse(url))) {
                                                    await launchUrl(Uri.parse(url));
                                                  }
                                                },
                                                child: Row(
                                                  children: [
                                                    const Icon(
                                                      Icons.location_on,
                                                      size: 14,
                                                      color: Colors.red,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      'View on Map',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: Colors.blue[700],
                                                        decoration: TextDecoration.underline,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                )).toList(),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Edit Messages Section
          if (_editMessages.isNotEmpty) ...[
            Container(
              height: 200,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.chat, color: Colors.green),
                        SizedBox(width: 8),
                        Text(
                          'Edit History',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(12),
                      itemCount: _editMessages.length,
                      itemBuilder: (context, index) {
                        final message = _editMessages[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: message.isUser 
                                      ? Colors.blue.withOpacity(0.1)
                                      : Colors.grey.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      message.isUser ? Icons.person : Icons.smart_toy,
                                      size: 16,
                                      color: message.isUser ? Colors.blue : Colors.grey[600],
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        message.text,
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Display the new itinerary if available
                              if (message.itinerary != null) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.green.withOpacity(0.2),
                                      width: 1,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        message.itinerary!['title'] ?? 'New Trip',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: Colors.green,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Duration: ${message.itinerary!['startDate']} to ${message.itinerary!['endDate']}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      ElevatedButton.icon(
                                        onPressed: () {
                                          // Option to replace current trip with new one
                                          setState(() {
                                            _currentTrip = _convertJsonToTrip(message.itinerary!);
                                          });
                                        },
                                        icon: const Icon(Icons.swap_horiz, size: 16),
                                        label: const Text('Use This Version'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green,
                                          foregroundColor: Colors.white,
                                          minimumSize: const Size(0, 32),
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          textStyle: const TextStyle(fontSize: 12),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          
          // Edit Input Section
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                const Row(
                  children: [
                    Icon(Icons.edit, color: Colors.orange),
                    SizedBox(width: 8),
                    Text(
                      'Modify Your Trip',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _editController,
                  maxLines: 5,
                  minLines: 5,
                  decoration: InputDecoration(
                    hintText: 'E.g., "Add a visit to the Eiffel Tower on day 2" or "Change day 1 lunch to a sushi restaurant"',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isModifying ? null : _modifyTrip,
                    icon: _isModifying 
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_fix_high),
                    label: Text(_isModifying ? 'Modifying...' : 'Apply Changes'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final Map<String, dynamic>? itinerary;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.itinerary,
  });
}
