import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../presentation/services/token_manager.dart';

Future<Map<String, dynamic>> fetchItineraryFromGemini(String prompt, String apiKey) async {
  final tokenManager = TokenManager.getInstance();
  final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent');
  
  final enhancedPrompt = '''
Generate a travel itinerary in EXACTLY this JSON format. Do not add any extra fields:

{
  "title": "Trip Title",
  "days": [
    {
      "date": "Day 1",
      "summary": "Day summary",
      "items": [
        {
          "time": "HH:MM",
          "activity": "Activity description", 
          "lat": 00.0000000,
          "lng": 00.0000000
        }
      ]
    }
  ]
}

User's request: $prompt

RULES:
- Use ONLY these 4 fields: time, activity, lat, lng
- DO NOT include any other fields
- Use accurate coordinates for each location mentioned
- Use 24-hour time format (HH:MM)
- For the "date" field in days array, use "Day 1", "Day 2", "Day 3" format
- Return only valid JSON without any markdown formatting

SCHEDULING RULES:
- DO NOT increase the number of days unless the user explicitly requests more days.
- Fit all activities within the number of days and time specified by the user.
- If there are too many activities, prioritize user-requested items and replace less important ones as needed.
- Only include activities the user asks for, unless there is extra time in the schedule.

ACTIVITY DESCRIPTION RULES:
- Keep activity descriptions SHORT, CLEAN, and RELEVANT
- You may include a bit of detail about the activity (e.g. what to see, what to do, what is special), but keep it concise and focused on the experience.
- DO NOT include full addresses, pin codes, or street details in activity text
- DO NOT mention costs, prices, budget, or money
- DO NOT include URLs or website links
- DO NOT include tips, suggestions, advice, or recommendations
- DO NOT mention "consider visiting early", "take an auto-rickshaw", "pro tips", etc.
- Focus ONLY on the activity itself
- Example: "Visit Madan Mahal Fort and see the ancient architecture" instead of "Visit Madan Mahal Fort and enjoy panoramic views. Consider visiting early."
- Example: "Lunch at local restaurant and try local cuisine" instead of "Lunch at restaurant and try their specialties"
''';

  final body = jsonEncode({
    "contents": [
      {
        "parts": [
          {
            "text": enhancedPrompt
          }
        ]
      }
    ],
    "generationConfig": {
      "temperature": 0.7,
      "topK": 40,
      "topP": 0.95,
      "maxOutputTokens": 4096,
    }
  });

  print('Calling Gemini API with key: ${apiKey.isNotEmpty ? "Key provided" : "No key"}');

  final response = await http.post(
    url, 
    headers: {
      'Content-Type': 'application/json',
      'x-goog-api-key': apiKey,
    }, 
    body: body
  );

  print('Response status: ${response.statusCode}');
  print('Response body: ${response.body}');

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    
    // Track tokens if usage info is available
    try {
      if (data['usageMetadata'] != null) {
        final usage = data['usageMetadata'];
        final promptTokens = usage['promptTokenCount'] ?? 0;
        final candidatesTokens = usage['candidatesTokenCount'] ?? 0;
        
        await tokenManager.addRequestTokens(promptTokens);
        await tokenManager.addResponseTokens(candidatesTokens);
        
        print('Token usage - Request: $promptTokens, Response: $candidatesTokens');
      } else {
        // Fallback: estimate tokens if not provided by API
        final requestTokens = _estimateTokens(enhancedPrompt);
        final responseTokens = _estimateTokens(response.body);
        
        await tokenManager.addRequestTokens(requestTokens);
        await tokenManager.addResponseTokens(responseTokens);
        
        print('Estimated token usage - Request: $requestTokens, Response: $responseTokens');
      }
      
      // Increment session count
      await tokenManager.incrementSessionCount();
    } catch (e) {
      print('Error tracking tokens: $e');
    }
    
    if (data['candidates'] != null && data['candidates'].isNotEmpty) {
      final candidate = data['candidates'][0];
      if (candidate['content'] != null && candidate['content']['parts'] != null) {
        final parts = candidate['content']['parts'] as List;
        
        if (parts.isNotEmpty && parts[0]['text'] != null) {
          String textResponse = parts[0]['text'] as String;
          
          // Clean the response
          textResponse = textResponse.trim();
          if (textResponse.startsWith('```json')) {
            textResponse = textResponse.substring(7); // Remove ```json
          }
          if (textResponse.startsWith('```')) {
            textResponse = textResponse.substring(3); // Remove ```
          }
          if (textResponse.endsWith('```')) {
            textResponse = textResponse.substring(0, textResponse.length - 3); // Remove ```
          }
          textResponse = textResponse.trim();
          
          textResponse = _cleanJsonString(textResponse);
          
          try {
            print('=== GEMINI RAW RESPONSE ===');
            print(textResponse);
            print('=== END GEMINI RESPONSE ===');
            
            final itinerary = jsonDecode(textResponse);
            
            // Check if the response contains the expected fields
            print('=== CHECKING RESPONSE STRUCTURE ===');
            if (itinerary['days'] != null) {
              final days = itinerary['days'] as List;
              if (days.isNotEmpty && days[0]['items'] != null) {
                final items = days[0]['items'] as List;
                if (items.isNotEmpty) {
                  final firstItem = items[0];
                  print('First item structure: ${firstItem.keys.toList()}');
                  print('Has lat field: ${firstItem.containsKey('lat')}');
                  print('Has lng field: ${firstItem.containsKey('lng')}');
                  print('Activity: ${firstItem['activity']}');
                }
              }
            }
            print('=== END STRUCTURE CHECK ===');
            
            if (_isValidItinerary(itinerary)) {
              final result = Map<String, dynamic>.from(itinerary as Map<String, dynamic>);
              return result;
            } else {
              print('Invalid itinerary structure');
              // Try to fix the JSON structure
              final fixedJson = _tryFixJsonStructure(textResponse);
              if (fixedJson != null) {
                final retryItinerary = jsonDecode(fixedJson);
                if (_isValidItinerary(retryItinerary)) {
                  final result = Map<String, dynamic>.from(retryItinerary as Map<String, dynamic>);
                  return result;
                }
              }
            }
          } catch (e) {
            print('JSON parsing failed: $e');
            print('Raw text length: ${textResponse.length}');
            print('First 200 chars: ${textResponse.length > 200 ? textResponse.substring(0, 200) : textResponse}');
            
            // Try to fix the JSON
            try {
              final fixedJson = _tryFixJsonStructure(textResponse);
              if (fixedJson != null) {
                final retryItinerary = jsonDecode(fixedJson);
                if (_isValidItinerary(retryItinerary)) {
                  final result = Map<String, dynamic>.from(retryItinerary as Map<String, dynamic>);
                  return result;
                }
              }
            } catch (e2) {
              print('JSON fix attempt also failed: $e2');
            }
            
            throw Exception('Failed to parse itinerary JSON: $e\nRaw text: $textResponse');
          }
        }
      }
    }
    
    // Fallback response
    return {
      'title': 'Trip Planning Error',
      'days': [],
    };
  }
  
  throw Exception('Failed to fetch itinerary: ${response.statusCode} - ${response.body}');
}

String? _tryFixJsonStructure(String jsonString) {
  try {
    // Remove any trailing commas
    jsonString = jsonString.replaceAll(RegExp(r',(\s*[}\]])'), r'$1');
    
    // Try to extract JSON from the middle of text
    final jsonStart = jsonString.indexOf('{');
    final jsonEnd = jsonString.lastIndexOf('}');
    
    if (jsonStart != -1 && jsonEnd != -1 && jsonEnd > jsonStart) {
      String extracted = jsonString.substring(jsonStart, jsonEnd + 1);
      
      // Clean up common issues
      extracted = extracted.replaceAll(RegExp(r'\n\s*'), ' ');
      extracted = extracted.replaceAll(RegExp(r'\s+'), ' ');
      extracted = _cleanJsonString(extracted);
      
      return extracted;
    }
  } catch (e) {
    print('JSON fix attempt failed: $e');
  }
  return null;
}

bool _isValidItinerary(dynamic data) {
  if (data is! Map<String, dynamic>) return false;
  
  // Check required fields
  if (!data.containsKey('title') || 
      !data.containsKey('days')) {
    return false;
  }
  
  // Check if days is a list
  if (data['days'] is! List) return false;
  
  final days = data['days'] as List;
  
  // Check each day has required structure
  for (final day in days) {
    if (day is! Map<String, dynamic>) return false;
    if (!day.containsKey('date') || !day.containsKey('items')) return false;
    if (day['items'] is! List) return false;
    
    final items = day['items'] as List;
    for (final item in items) {
      if (item is! Map<String, dynamic>) return false;
      if (!item.containsKey('time') || !item.containsKey('activity')) return false;
    }
  }
  
  return true;
}

String _cleanJsonString(String jsonString) {
  // Remove any non-printable characters except newlines and tabs
  jsonString = jsonString.replaceAll(RegExp(r'[^\x20-\x7E\n\t]'), '');
  
  // Fix common JSON issues
  jsonString = jsonString.replaceAll(''', "'"); // Smart quotes
  jsonString = jsonString.replaceAll(''', "'");
  jsonString = jsonString.replaceAll('"', '"'); // Smart double quotes
  jsonString = jsonString.replaceAll('"', '"');
  
  // Remove any trailing commas before closing brackets
  jsonString = jsonString.replaceAll(RegExp(r',(\s*[}\]])'), r'$1');
  
  return jsonString.trim();
}

// Helper function to estimate token count
int _estimateTokens(String text) {
  // Rough estimation: 1 token ≈ 4 characters for English text
  return (text.length / 4).ceil();
}
