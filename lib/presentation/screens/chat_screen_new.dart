import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../data/datasources/gemini_api.dart';
import '../../data/models/itinerary.dart';
import '../../data/repositories/isar_repository.dart';
import 'dart:convert';

class ChatScreen extends StatefulWidget {
  const ChatScreen({Key? key}) : super(key: key);
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<ChatMessage> _messages = [];
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isCreatingTrip = false;
  Map<String, dynamic>? _currentItinerary;
  List<Itinerary> _savedTrips = [];
  late IsarRepository _repository;
  final GeminiAPI _geminiAPI = GeminiAPI();

  @override
  void initState() {
    super.initState();
    _initializeRepository();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeRepository() async {
    _repository = IsarRepository();
    await _repository.initialize();
    _loadSavedTrips();
  }

  Future<void> _loadSavedTrips() async {
    try {
      final trips = await _repository.getAllItineraries();
      setState(() {
        _savedTrips = trips;
      });
    } catch (e) {
      print('Error loading saved trips: $e');
    }
  }

  Future<void> _createTrip() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    setState(() {
      _isCreatingTrip = true;
      _messages.add(ChatMessage(
        text: message,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _messageController.clear();
    });

    _scrollToBottom();

    try {
      final response = await _geminiAPI.generateItinerary(message);
      final itinerary = json.decode(response);
      
      setState(() {
        _currentItinerary = itinerary;
        _messages.add(ChatMessage(
          text: "I've created your trip itinerary! Here are the details:",
          isUser: false,
          timestamp: DateTime.now(),
          itinerary: itinerary,
        ));
        _isCreatingTrip = false;
      });

      _scrollToBottom();
    } catch (e) {
      setState(() {
        _messages.add(ChatMessage(
          text: "Sorry, I encountered an error while creating your trip. Please try again.",
          isUser: false,
          timestamp: DateTime.now(),
        ));
        _isCreatingTrip = false;
      });
    }
  }

  Future<void> _saveItinerary() async {
    if (_currentItinerary == null) return;

    try {
      final itinerary = Itinerary()
        ..title = _currentItinerary!['title'] ?? 'Untitled Trip'
        ..startDate = _currentItinerary!['startDate'] ?? ''
        ..endDate = _currentItinerary!['endDate'] ?? ''
        ..days = []; // We'll convert the itinerary data to proper format later

      await _repository.saveItinerary(itinerary);
      await _loadSavedTrips();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Trip saved successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving trip: $e')),
        );
      }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Smart Trip Planner'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.pushNamed(context, '/memory'),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_messages.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.travel_explore,
                      size: 64,
                      color: Colors.blue,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Welcome to Smart Trip Planner',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Tell me about your dream trip and I\'ll create a perfect itinerary for you!',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final message = _messages[index];
                  return _buildMessageBubble(message);
                },
              ),
            ),
          if (_isCreatingTrip)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(width: 16),
                  Text(
                    'Creating your trip...',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.8,
            ),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: message.isUser ? Colors.blue[50] : Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: message.isUser ? Colors.blue : Colors.grey[300]!,
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      message.isUser ? Icons.person : Icons.smart_toy,
                      color: message.isUser ? Colors.blue : Colors.grey[600],
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      message.isUser ? 'You' : 'AI Assistant',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: message.isUser ? Colors.blue : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  message.text,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                  ),
                ),
                if (message.itinerary != null) ...[
                  const SizedBox(height: 12),
                  _buildItineraryCard(message.itinerary!),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItineraryCard(Map<String, dynamic> itinerary) {
    return Card(
      color: Colors.white,
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              itinerary['title'] ?? 'Trip Itinerary',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Destination: ${itinerary['destination'] ?? 'Not specified'}',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black,
              ),
            ),
            Text(
              'Duration: ${itinerary['duration'] ?? 'Not specified'}',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 16),
            if (itinerary['itinerary'] != null)
              ...(_buildItineraryDays(itinerary['itinerary'] as List)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _saveItinerary,
              icon: const Icon(Icons.save),
              label: const Text('Save Trip'),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildItineraryDays(List itinerary) {
    return itinerary.map<Widget>((day) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              day['day'],
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),
          const SizedBox(height: 12),
          ...(_buildDayItems(day['items'] as List)),
          const SizedBox(height: 20),
        ],
      );
    }).toList();
  }

  List<Widget> _buildDayItems(List items) {
    return items.map<Widget>((item) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          '⏰ ${item['time']} - ${item['activity']}',
          style: const TextStyle(
            fontSize: 15,
            color: Colors.black,
            height: 1.4,
          ),
        ),
      );
    }).toList();
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey[300]!),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Describe your dream trip...',
                hintStyle: const TextStyle(color: Colors.grey),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: Colors.blue),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              maxLines: null,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _createTrip(),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: const BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: _createTrip,
              icon: const Icon(Icons.send, color: Colors.white),
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
