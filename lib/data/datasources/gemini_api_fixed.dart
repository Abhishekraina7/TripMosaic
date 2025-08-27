import 'dart:convert';
import 'package:http/http.dart' as http;

Future<Map<String, dynamic>> fetchItineraryFromGemini(String prompt, String apiKey) async {
  final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent');
  
  final enhancedPrompt = '''
Generate a detailed travel itinerary in the following exact JSON format. Include precise coordinates, nearby attractions, and useful information. Do not include any extra text or explanations, just return the JSON:

{
  "title": "Trip Title",
  "startDate": "YYYY-MM-DD",
  "endDate": "YYYY-MM-DD",
  "days": [
    {
      "date": "YYYY-MM-DD",
      "summary": "Day summary",
      "items": [
        {
          "time": "HH:MM AM/PM",
          "activity": "Activity description",
          "location": "Location name with coordinates (latitude,longitude)"
        }
      ]
    }
  ]
}

User's request: $prompt

IMPORTANT: 
1. Include exact coordinates in format (latitude,longitude) for each location
2. Generate Google Maps Place URLs for major attractions
3. Keep the response as valid JSON only
4. Include practical details like timings and nearby attractions
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
      "maxOutputTokens": 2048,
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
            print('Extracted JSON text: $textResponse');
            final itinerary = jsonDecode(textResponse);
            
            if (_isValidItinerary(itinerary)) {
              return itinerary as Map<String, dynamic>;
            } else {
              print('Invalid itinerary structure');
              // Try to fix the JSON structure
              final fixedJson = _tryFixJsonStructure(textResponse);
              if (fixedJson != null) {
                final retryItinerary = jsonDecode(fixedJson);
                if (_isValidItinerary(retryItinerary)) {
                  return retryItinerary as Map<String, dynamic>;
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
                  return retryItinerary as Map<String, dynamic>;
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
      'startDate': DateTime.now().toIso8601String().split('T')[0],
      'endDate': DateTime.now().add(Duration(days: 3)).toIso8601String().split('T')[0],
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
      !data.containsKey('startDate') || 
      !data.containsKey('endDate') ||
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
