import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'dart:convert';
import '../../data/datasources/gemini_api.dart';
import '../../data/models/itinerary.dart';
import '../../data/repositories/isar_repository.dart';
import '../widgets/message_widgets.dart';
import 'token_manager_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({Key? key}) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late IsarRepository _repository;
  
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;
  bool _isTyping = false;
  String _currentTypingMessage = '';
  int _typingIndex = 0;

  @override
  void initState() {
    super.initState();
    _repository = IsarRepository.getInstance();
    _loadConversationHistory();
  }

  @overrid
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadConversationHistory() async {
    try {
      final itineraries = await _repository.getAllItineraries();
      // For now, just load an empty conversation since we don't have conversation storage
      setState(() {
        _messages = [];
      });
      _scrollToBottom();
    } catch (e) {
      print('Error loading conversation history: $e');
    }
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

  Future<void> _sendMessage() async {
    final message = _controller.text.trim();
    if (message.isEmpty) return;

    // Special command to clear all saved trips
    if (message.toLowerCase() == 'clear all trips') {
      await _repository.clearAllItineraries();
      setState(() {
        _messages.add({
          'text': message,
          'isUser': true,
          'timestamp': DateTime.now().toIso8601String(),
        });
      });
      _controller.clear();
      
      final clearMessage = 'All saved trips have been cleared! 🗑️\n\nNow all new trips will be saved with the clean JSON format you specified.';
      _startTypingAnimation(clearMessage);
      return;
    }

    setState(() {
      _messages.add({
        'text': message,
        'isUser': true,
        'timestamp': DateTime.now().toIso8601String(),
      });
      _isLoading = true;
    });

    _controller.clear();
    _scrollToBottom();

    try {
      // Location services are disabled - removed map service integration
      String? location = 'Location services disabled - using manual location input only';
      String? coordinatesInfo = 'Map service removed from app';

      // Enhanced prompt with advanced features and Google Place URLs
      final enhancedMessage = '''
$message

${location ?? 'No location data available'}

IMPORTANT INSTRUCTIONS:
1. Include specific locations with clear names and addresses
2. For each major location, provide detailed descriptions
3. Calculate approximate travel times between locations  
4. Suggest places of interest near each location (restaurants, attractions, viewpoints)
5. Include relevant URLs for major attractions, restaurants, and accommodations
6. Consider travel time and distances between locations
7. Suggest optimal routes and transportation methods
8. Include local recommendations and hidden gems
9. Provide practical information like opening hours and contact details
10. Consider weather and seasonal factors for the destination
11. Include emergency contacts and useful local information

For each activity, please provide:
- Exact location/address with clear place names
- Nearby points of interest (within 2-3 km)
- Recommended duration of visit
- Best time to visit
- Useful URLs (official websites, booking links, maps)
- Alternative options if the main activity is unavailable

RESPONSE FORMAT:
Please structure your response as a detailed trip plan with:
- Clear location names and addresses
- Step-by-step itinerary with timings
- Transportation details
''';

      final apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
      final response = await fetchItineraryFromGemini(enhancedMessage, apiKey);
      
      if (response.containsKey('title')) {
        try {
          final itinerary = Itinerary()
            ..title = response['title']
            ..days = (response['days'] as List).map((dayData) {
              return ItineraryDay()
                ..date = dayData['date']
                ..summary = dayData['summary'] ?? ''
                ..items = (dayData['items'] as List).map((itemData) {
                  return ItineraryItem()
                    ..time = itemData['time']
                    ..activity = itemData['activity']
                    ..lat = (itemData['lat'] as num).toDouble()
                    ..lng = (itemData['lng'] as num).toDouble();
                }).toList();
            }).toList();
          
          await _repository.saveItinerary(itinerary);

          // Use the raw Gemini response for instant display
          final rawResponse = response['_rawResponse'] as String? ?? 'Trip created successfully!';
          
          final tripData = {
            'title': itinerary.title,
            'days': itinerary.days.map((day) => {
                  'date': day.date,
                  'summary': day.summary,
                  'items': day.items.map((item) => {
                    'time': item.time,
                    'activity': item.activity,
                    'lat': item.lat,
                    'lng': item.lng,
                  }).toList(),
                }).toList(),
              };
          
          // Add message instantly with trip data for map buttons
          _addInstantMessageWithTripData(rawResponse, tripData);
        } catch (e) {
          final errorMessage = 'I created a trip plan, but there was an error parsing it. Here\'s the response:\n\n${response.toString()}';
          // Show error messages instantly without typewriter effect
          _addInstantMessage(errorMessage);
        }
      } else {
        final responseMessage = response.toString();
        // Show simple responses instantly without typewriter effect  
        _addInstantMessage(responseMessage);
      }

      await _saveConversation();
    } catch (e) {
      final errorMessage = 'Sorry, I encountered an error while processing your request. Please try again or rephrase your question.';
      // Show error messages instantly without typewriter effect
      _addInstantMessage(errorMessage);
    } finally {
      setState(() {
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  Future<void> _saveConversation() async {
    // For now, we don't persist conversations - only itineraries
    return;
  }

  // Typewriter effect method
  void _startTypingAnimation(String fullMessage, {Map<String, dynamic>? tripData}) {
    setState(() {
      _isTyping = true;
      _currentTypingMessage = '';
      _typingIndex = 0;
    });

    // Add the message placeholder
    final messageIndex = _messages.length;
    _messages.add({
      'text': '',
      'isUser': false,
      'timestamp': DateTime.now().toIso8601String(),
      'isTyping': true,
      if (tripData != null) 'trip': tripData,
    });

    // Start the typewriter animation
    const typingSpeed = Duration(milliseconds: 30); // Adjust speed here
    
    Timer.periodic(typingSpeed, (timer) {
      if (_typingIndex < fullMessage.length) {
        setState(() {
          _currentTypingMessage = fullMessage.substring(0, _typingIndex + 1);
          _messages[messageIndex]['text'] = _currentTypingMessage;
        });
        _typingIndex++;
        _scrollToBottom();
      } else {
        // Animation complete
        timer.cancel();
        setState(() {
          _isTyping = false;
          _messages[messageIndex]['isTyping'] = false;
          _messages[messageIndex]['text'] = fullMessage;
        });
      }
    });
  }

  void _addInstantMessage(String message) {
    setState(() {
      _isTyping = false;
      _messages.add({
        'text': message,
        'isUser': false,
        'timestamp': DateTime.now().toIso8601String(),
        'isTyping': false,
      });
    });
    _scrollToBottom();
  }

  void _addInstantMessageWithTripData(String message, Map<String, dynamic> tripData) {
    setState(() {
      _isTyping = false;
      _messages.add({
        'text': message,
        'isUser': false,
        'timestamp': DateTime.now().toIso8601String(),
        'isTyping': false,
        'trip': tripData,
      });
    });
    _scrollToBottom();
  }

  void _onTripTap(Itinerary trip) {
    // Navigation to trip details disabled - stay on chat screen
    // Users can interact with trip details directly in the message
    return;
  }

  void _showAllTripsDialog(List<Itinerary> allTrips) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'All Saved Trips (${allTrips.length})',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: allTrips.length,
                itemBuilder: (context, index) {
                  final trip = allTrips[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          Navigator.pop(context);
                          _onTripTap(trip);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.flight_takeoff,
                                  color: Colors.blue[600],
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      trip.title,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${trip.days.length} days',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${trip.days.length} days',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.blue[600],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.arrow_forward_ios,
                                size: 16,
                                color: Colors.grey[400],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not launch $url')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _messages.isEmpty ? AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(''),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: Colors.blue[800]),
            onSelected: (value) {
              if (value == 'token_manager') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TokenManagerScreen(),
                  ),
                );
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'token_manager',
                child: Row(
                  children: [
                    Icon(Icons.analytics, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('Token Manager'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ) : null,
      body: SafeArea(
        child: Column(
          children: [
            // Top section with title - only show on landing page
            if (_messages.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    Text(
                      'Smart Trip Planner',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[800],
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Plan your perfect journey with AI',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            
            // Main content area
            Expanded(
              child: _messages.isEmpty
                  ? _buildLandingPage()
                  : _buildChatView(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLandingPage() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenHeight = constraints.maxHeight;
        final isSmallScreen = screenHeight < 600;
        
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: screenHeight,
            ),
            child: Column(
              children: [
                SizedBox(height: isSmallScreen ? 10 : 20), // Very close to top
                
                // Squircle message entry box - moved higher up
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        spreadRadius: 0,
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _controller,
                    textAlignVertical: TextAlignVertical.top,
                    decoration: InputDecoration(
                      hintText: 'Where would you like to go?',
                      hintStyle: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(28),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: isSmallScreen ? 35 : 50,
                      ),
                    ),
                    maxLines: null,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                
                SizedBox(height: isSmallScreen ? 10 : 20), // Very close to top
                
                // Create Trip Button
                Container(
                  width: double.infinity,
                  height: isSmallScreen ? 48 : 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    gradient: LinearGradient(
                      colors: [Colors.blue[600]!, Colors.blue[800]!],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.3),
                        spreadRadius: 0,
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _sendMessage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    child: _isLoading
                        ? SizedBox(
                            width: isSmallScreen ? 20 : 24,
                            height: isSmallScreen ? 20 : 24,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(
                            'Create Trip',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 14 : 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
                
                SizedBox(height: isSmallScreen ? 24 : 40),
                
                // Saved Trips Section
                _buildSavedTripsSection(),
                
                // Bottom spacing
                SizedBox(height: isSmallScreen ? 20 : 40),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSavedTripsSection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenHeight = MediaQuery.of(context).size.height;
        final isSmallScreen = screenHeight < 600;
        final isMediumScreen = screenHeight >= 600 && screenHeight < 800;
        
        // Determine number of trips to show based on screen size
        int tripsToShow;
        if (isSmallScreen) {
          tripsToShow = 1; // Very small screens - show only 1 trip
        } else if (isMediumScreen) {
          tripsToShow = 2; // Medium screens - show 2 trips
        } else {
          tripsToShow = 3; // Large screens - show 3 trips
        }
        
        return FutureBuilder<List<Itinerary>>(
          future: _repository.getAllItineraries(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Container(
                padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.explore_outlined,
                      size: isSmallScreen ? 40 : 48,
                      color: Colors.grey[400],
                    ),
                    SizedBox(height: isSmallScreen ? 8 : 12),
                    Text(
                      'No saved trips yet',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 14 : 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[600],
                      ),
                    ),
                    SizedBox(height: isSmallScreen ? 4 : 8),
                    Text(
                      'Create your first trip to get started!',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 11 : 12,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              );
            }
            
            final trips = snapshot.data!;
            final displayTrips = trips.take(tripsToShow).toList();
            final hasMoreTrips = trips.length > tripsToShow;
            
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Recent Trips',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 16 : 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                    if (hasMoreTrips)
                      TextButton(
                        onPressed: () => _showAllTripsModal(),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                            horizontal: isSmallScreen ? 8 : 12,
                            vertical: isSmallScreen ? 4 : 8,
                          ),
                        ),
                        child: Text(
                          'See All (${trips.length})',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 11 : 12,
                            color: Colors.blue[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
                SizedBox(height: isSmallScreen ? 12 : 16),
                ...displayTrips.map((itinerary) => Padding(
                  padding: EdgeInsets.only(bottom: isSmallScreen ? 8 : 12),
                  child: _buildTripCard(itinerary, isSmallScreen),
                )),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildTripCard(Itinerary itinerary, [bool isSmallScreen = false]) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            spreadRadius: 0,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _navigateToTripView(itinerary),
          child: Padding(
            padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
            child: Row(
              children: [
                Container(
                  width: isSmallScreen ? 40 : 48,
                  height: isSmallScreen ? 40 : 48,
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.location_on,
                    color: Colors.blue[600],
                    size: isSmallScreen ? 20 : 24,
                  ),
                ),
                SizedBox(width: isSmallScreen ? 12 : 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        itinerary.title ?? 'Trip',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 13 : 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: isSmallScreen ? 2 : 4),
                      Text(
                        '${itinerary.days.length} days',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 10 : 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                // Action buttons
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.edit,
                        color: Colors.orange[600],
                        size: isSmallScreen ? 18 : 20,
                      ),
                      onPressed: () => _editTrip(itinerary),
                      padding: EdgeInsets.all(isSmallScreen ? 4 : 8),
                      constraints: BoxConstraints(
                        minWidth: isSmallScreen ? 32 : 36,
                        minHeight: isSmallScreen ? 32 : 36,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.delete,
                        color: Colors.red[600],
                        size: isSmallScreen ? 18 : 20,
                      ),
                      onPressed: () => _deleteTrip(itinerary),
                      padding: EdgeInsets.all(isSmallScreen ? 4 : 8),
                      constraints: BoxConstraints(
                        minWidth: isSmallScreen ? 32 : 36,
                        minHeight: isSmallScreen ? 32 : 36,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChatView() {
    return Column(
      children: [
        // Back button header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black),
                onPressed: () {
                  setState(() {
                    _messages.clear();
                  });
                },
              ),
              const Text(
                'Trip Chat',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final message = _messages[index];
              final messageText = message['text'] as String;
              final isUser = message['isUser'] as bool;
              final isError = message['isError'] as bool? ?? false;
              final isTyping = message['isTyping'] as bool? ?? false;
              final tripData = message['trip'] as Map<String, dynamic>?;

              if (tripData != null) {
                final trip = Itinerary()
                  ..title = tripData['title']
                  ..days = (tripData['days'] as List).map((dayData) {
                    return ItineraryDay()
                      ..date = dayData['date']
                      ..summary = dayData['summary'] ?? ''
                      ..items = (dayData['items'] as List).map((itemData) {
                        return ItineraryItem()
                          ..time = itemData['time']
                          ..activity = itemData['activity']
                          ..lat = (itemData['lat'] as num?)?.toDouble() ?? 0.0
                          ..lng = (itemData['lng'] as num?)?.toDouble() ?? 0.0;
                      }).toList();
                  }).toList();
                return TripMessageBubble(
                  message: messageText,
                  trip: trip,
                );
              }

              return MessageBubble(
                message: messageText,
                isUser: isUser,
                isError: isError,
                isTyping: isTyping,
                onTap: messageText.contains('http') 
                    ? () => _launchURL(messageText) 
                    : null,
              );
            },
          ),
        ),
        if (_isLoading)
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 12),
                Text(
                  'AI is planning your trip...',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              top: BorderSide(color: Colors.grey[300]!),
            ),
          ),
          child: Column(
            children: [
              // Modern squircle message input
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: Colors.grey[200]!),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      spreadRadius: 0,
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        decoration: InputDecoration(
                          hintText: 'Continue the conversation...',
                          hintStyle: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 14,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 32, // Increased height
                          ),
                        ),
                        minLines: 3, // Minimum height for editing
                        maxLines: null,
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Modern "Modify Trip" button
              Container(
                width: double.infinity,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.orange[600]!, Colors.orange[800]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withOpacity(0.3),
                      spreadRadius: 0,
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _sendMessage,
                  icon: const Icon(
                    Icons.auto_fix_high_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  label: const Text(
                    'Modify Trip',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _editTrip(Itinerary itinerary) {
    // Pre-fill the text controller with the trip title for editing context
    _controller.text = itinerary.title ?? '';
    
    // Add the trip details as a message to show current itinerary
    setState(() {
      _messages.clear(); // Clear previous messages
      _messages.add({
        'text': 'Here is your current trip. What would you like to modify?',
        'isUser': false,
        'isError': false,
        'trip': {
          'title': itinerary.title,
          'days': itinerary.days.map((day) => {
            'date': day.date,
            'summary': day.summary,
            'items': day.items.map((item) => {
              'time': item.time,
              'activity': item.activity,
              'lat': item.lat,
              'lng': item.lng,
            }).toList(),
          }).toList(),
        },
      });
    });
    
    // Scroll to bottom to show the trip
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

  void _deleteTrip(Itinerary itinerary) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Trip'),
          content: Text('Are you sure you want to delete "${itinerary.title ?? 'this trip'}"?'),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.red),
              ),
              onPressed: () async {
                try {
                  await _repository.deleteItinerary(itinerary.id);
                  Navigator.of(context).pop();
                  setState(() {}); // Refresh the UI
                  
                  // Show success message
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Trip "${itinerary.title ?? 'Untitled'}" deleted successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  Navigator.of(context).pop();
                  
                  // Show error message
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error deleting trip: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _navigateToTripView(Itinerary itinerary) {
    // Navigation to trip view disabled - keep users on chat screen
    // All trip interactions can be done directly in the message bubbles
    return;
  }

  void _showAllTripsModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'All Saved Trips',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<List<Itinerary>>(
                future: _repository.getAllItineraries(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(
                      child: Text('No trips found'),
                    );
                  }
                  
                  final itineraries = snapshot.data!;
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: itineraries.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildTripCard(itineraries[index], false),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
