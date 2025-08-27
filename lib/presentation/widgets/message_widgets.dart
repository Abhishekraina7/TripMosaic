import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/models/itinerary.dart';

// Reusable Message Widget Classes
class MessageBubble extends StatelessWidget {
  final String message;
  final bool isUser;
  final bool isError;
  final bool isTyping;
  final VoidCallback? onTap;

  const MessageBubble({
    Key? key,
    required this.message,
    this.isUser = false,
    this.isError = false,
    this.isTyping = false,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            _buildAvatar(),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _getBackgroundColor(),
                borderRadius: _getBorderRadius(),
                border: Border.all(
                  color: _getBorderColor(),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: onTap,
                          child: Text(
                            message,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: _getTextColor(),
                            ),
                          ),
                        ),
                      ),
                      if (isTyping && !isUser) ...[
                        const SizedBox(width: 8),
                        _buildTypingIndicator(),
                      ],
                    ],
                  ),
                  // Add smart map links for AI responses
                  if (!isUser && !isError) ..._buildSmartMapLinks(),
                ],
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 12),
            _buildAvatar(),
          ],
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: _getAvatarBackgroundColor(),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Icon(
        _getAvatarIcon(),
        color: _getAvatarIconColor(),
        size: 20,
      ),
    );
  }

  Color _getBackgroundColor() {
    if (isUser) return Colors.blue.withOpacity(0.1);
    if (isError) return Colors.red.withOpacity(0.1);
    return Colors.green.withOpacity(0.1);
  }

  BorderRadius _getBorderRadius() {
    return isUser
        ? const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(4),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(16),
          )
        : const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(16),
          );
  }

  Color _getBorderColor() {
    if (isUser) return Colors.blue.withOpacity(0.3);
    if (isError) return Colors.red.withOpacity(0.3);
    return Colors.green.withOpacity(0.3);
  }

  Color _getTextColor() {
    if (isUser) return Colors.blue[800]!;
    if (isError) return Colors.red[800]!;
    return Colors.green[800]!;
  }

  Color _getAvatarBackgroundColor() {
    if (isUser) return Colors.blue.withOpacity(0.2);
    if (isError) return Colors.red.withOpacity(0.2);
    return Colors.green.withOpacity(0.2);
  }

  IconData _getAvatarIcon() {
    if (isUser) return Icons.person;
    if (isError) return Icons.error;
    return Icons.smart_toy;
  }

  Color _getAvatarIconColor() {
    if (isUser) return Colors.blue;
    if (isError) return Colors.red;
    return Colors.green;
  }

  List<Widget> _buildSmartMapLinks() {
    // Generate smart map links based on message content
    final links = _generateSmartMapLinks(message);
    
    if (links.isEmpty) return [];
    
    // Show only the first (most relevant) link
    final link = links.first;
    
    return [
      const SizedBox(height: 8),
      GestureDetector(
        onTap: () async {
          final uri = Uri.parse(link['url']!);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        },
        child: Container(
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.withOpacity(0.3)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.map,
                size: 16,
                color: Colors.blue[700],
              ),
              const SizedBox(width: 6),
              Text(
                link['label']!,
                style: TextStyle(
                  color: Colors.blue[700],
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    ];
  }

  List<Map<String, String>> _generateSmartMapLinks(String text) {
    final List<Map<String, String>> links = [];
    final lowercaseText = text.toLowerCase();
    
    // Your coordinates (Bheda area)
    const baseCoords = "22.2036422,76.1144807,11z";
    
    // Check for specific location names (like "bheda", "indore", etc.)
    final locationPattern = RegExp(r'\b[A-Z][a-zA-Z]+(?:\s+[A-Z][a-zA-Z]+)*\b');
    final matches = locationPattern.allMatches(text);
    
    final commonWords = {
      'The', 'And', 'Or', 'But', 'In', 'On', 'At', 'To', 'For', 'With', 'By',
      'Day', 'Time', 'Place', 'Location', 'Trip', 'Visit', 'Go', 'Come', 'See',
      'Morning', 'Afternoon', 'Evening', 'Night', 'Today', 'Tomorrow', 'Yesterday',
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
      'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August',
      'September', 'October', 'November', 'December',
    };
    
    // First, look for specific locations
    for (final match in matches) {
      final location = match.group(0)!;
      
      if (!commonWords.contains(location) && location.length > 2) {
        final searchTerm = location.replaceAll(' ', '+');
        links.add({
          'label': 'Find $location',
          'url': 'https://www.google.com/maps/search/$searchTerm/@$baseCoords/data=!3m1!4b1?entry=ttu&g_ep=EgoyMDI1MDgxOS4wIKXMDSoASAFQAw%3D%3D',
        });
        break; // Only add one specific location link
      }
    }
    
    // If no specific location found, check for generic terms
    if (links.isEmpty) {
      if (lowercaseText.contains('restaurant')) {
        links.add({
          'label': 'Find Restaurants',
          'url': 'https://www.google.com/maps/search/restaurants+near+this+location/@$baseCoords/data=!3m1!4b1?entry=ttu&g_ep=EgoyMDI1MDgxOS4wIKXMDSoASAFQAw%3D%3D',
        });
      } else if (lowercaseText.contains('hotel')) {
        links.add({
          'label': 'Find Hotels',
          'url': 'https://www.google.com/maps/search/hotels+near+this+location/@$baseCoords/data=!3m1!4b1?entry=ttu&g_ep=EgoyMDI1MDgxOS4wIKXMDSoASAFQAw%3D%3D',
        });
      } else if (lowercaseText.contains('attraction')) {
        links.add({
          'label': 'Find Attractions',
          'url': 'https://www.google.com/maps/search/tourist+attractions+near+this+location/@$baseCoords/data=!3m1!4b1?entry=ttu&g_ep=EgoyMDI1MDgxOS4wIKXMDSoASAFQAw%3D%3D',
        });
      } else if (lowercaseText.contains('hospital')) {
        links.add({
          'label': 'Find Hospitals',
          'url': 'https://www.google.com/maps/search/hospitals+near+this+location/@$baseCoords/data=!3m1!4b1?entry=ttu&g_ep=EgoyMDI1MDgxOS4wIKXMDSoASAFQAw%3D%3D',
        });
      } else if (lowercaseText.contains('bank')) {
        links.add({
          'label': 'Find Banks',
          'url': 'https://www.google.com/maps/search/banks+near+this+location/@$baseCoords/data=!3m1!4b1?entry=ttu&g_ep=EgoyMDI1MDgxOS4wIKXMDSoASAFQAw%3D%3D',
        });
      }
    }
    
    return links;
  }

  Widget _buildTypingIndicator() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...List.generate(3, (index) => 
          Container(
            margin: EdgeInsets.only(right: index < 2 ? 3 : 0),
            child: _TypingDot(delay: index * 200),
          ),
        ),
      ],
    );
  }
}

class _TypingDot extends StatefulWidget {
  final int delay;
  
  const _TypingDot({required this.delay});
  
  @override
  State<_TypingDot> createState() => _TypingDotState();
}

class _TypingDotState extends State<_TypingDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) {
        _controller.repeat(reverse: true);
      }
    });
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: 4,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey[600]?.withOpacity(_animation.value),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }
}

class TripMessageBubble extends StatelessWidget {
  final String message;
  final Itinerary trip;

  const TripMessageBubble({
    Key? key,
    required this.message,
    required this.trip,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.2),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.smart_toy,
              color: Colors.green,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                    border: Border.all(
                      color: Colors.green.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    message,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.green[800],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Trip details widget with individual map buttons
                TripWidget(trip: trip),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /*
  List<Widget> _buildSmartMapLinksForTrip(Itinerary trip) {
    // This function is no longer used since we moved to individual map buttons
    // and switched from location strings to lat/lng coordinates
    return [];
  }
  */
}

class TripWidget extends StatefulWidget {
  final Itinerary trip;

  const TripWidget({
    Key? key,
    required this.trip,
  }) : super(key: key);

  @override
  State<TripWidget> createState() => _TripWidgetState();
}

class _TripWidgetState extends State<TripWidget> {
  
  Future<void> _openMap(double lat, double lng, String activity) async {
    // Extract the main search term from activity
    String searchTerm = activity;
    
    // Try to extract full address if present (look for patterns like pincode, state names, etc.)
    // Common patterns in Indian addresses: 6-digit pincode, state names, specific location formats
    RegExp addressPattern = RegExp(r'Address[:\s]*([^\.]+?)(?=\.|$)', caseSensitive: false);
    RegExp pincodePattern = RegExp(r'\b\d{6}\b'); // 6-digit pincode
    RegExp locationPattern = RegExp(r'[A-Z][a-zA-Z\s]+,\s*[A-Z][a-zA-Z\s]+,\s*[A-Z][a-zA-Z\s]+\s+\d{6}'); // Full address format
    
    Match? addressMatch = addressPattern.firstMatch(activity);
    if (addressMatch != null) {
      // Use the extracted address
      searchTerm = addressMatch.group(1)?.trim() ?? activity;
    } else if (pincodePattern.hasMatch(activity)) {
      // If there's a pincode, use the entire activity as it likely contains address
      searchTerm = activity;
    } else if (locationPattern.hasMatch(activity)) {
      // If it matches full address pattern, use as is
      searchTerm = activity;
    } else {
      // Clean up the activity text for better search results
      searchTerm = searchTerm.replaceAll(RegExp(r'\b(visit|go to|explore|see|at|in|near)\b', caseSensitive: false), '').trim();
    }
    
    searchTerm = Uri.encodeComponent(searchTerm);
    
    // Use the coordinates provided by Gemini for the center point
    // If coordinates are invalid, fall back to user location
    double centerLat = lat;
    double centerLng = lng;
    
    // Check if Gemini coordinates are valid
    bool areCoordinatesValid = lat != 0.0 && lng != 0.0 && 
                              !lat.isNaN && !lng.isNaN && 
                              lat.abs() <= 90 && lng.abs() <= 180;
    
    if (!areCoordinatesValid) {
      // Fallback to user location if Gemini coordinates are invalid
      centerLat = 22.2036422;
      centerLng = 76.1144807;
    }
    
    // Use search with the appropriate center point
    final url = 'https://www.google.com/maps/search/$searchTerm/@$centerLat,$centerLng,11z';
    
    print('DEBUG: Original activity: $activity');
    print('DEBUG: Extracted search term: ${Uri.decodeComponent(searchTerm)}');
    print('DEBUG: Using coordinates: $centerLat, $centerLng');
    print('DEBUG: Map URL: $url');
    
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      print('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.trip.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${widget.trip.days.length} days',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: widget.trip.days.map((day) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      day.date,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Colors.blue,
                      ),
                    ),
                    if (day.summary.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        day.summary,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    ...day.items.map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 50,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              item.time,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.activity,
                                  style: const TextStyle(fontSize: 11),
                                ),
                                const SizedBox(height: 4),
                                // Individual Map Button for each activity
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: GestureDetector(
                                    onTap: () => _openMap(item.lat, item.lng, item.activity),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.blue[600]!,
                                            Colors.blue[700]!,
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        borderRadius: BorderRadius.circular(20),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.blue.withOpacity(0.3),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.location_on,
                                            size: 14,
                                            color: Colors.white,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Open Map',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )).toList(),
                  ],
                ),
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
