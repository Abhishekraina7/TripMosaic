import 'package:flutter_dotenv/flutter_dotenv.dart';

String getGeminiApiKey() {
  return dotenv.env['GEMINI_API_KEY'] ?? '';
}

void main() {
  final itinerary = {
    "time": "10:00",
    "activity": "Arrive at Jabalpur Airport (JLR)", 
    "location": "Jabalpur Airport, Dumna, Madhya Pradesh 482005"
  };

  print(itinerary);
}
