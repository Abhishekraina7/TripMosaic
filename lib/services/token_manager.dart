import 'package:shared_preferences/shared_preferences.dart';

class TokenManager {
  static const String _requestTokensKey = 'request_tokens';
  static const String _responseTokensKey = 'response_tokens';
  static const String _totalRequestsKey = 'total_requests';
  
  static TokenManager? _instance;
  static TokenManager getInstance() {
    _instance ??= TokenManager();
    return _instance!;
  }

  // Track tokens for current session
  int _sessionRequestTokens = 0;
  int _sessionResponseTokens = 0;
  int _sessionRequests = 0;

  // Add tokens to the count
  Future<void> addTokens({
    required int requestTokens,
    required int responseTokens,
  }) async {
    _sessionRequestTokens += requestTokens;
    _sessionResponseTokens += responseTokens;
    _sessionRequests += 1;
    
    await _saveTokensToStorage();
  }

  // Estimate tokens (roughly 4 characters = 1 token for English)
  int estimateTokens(String text) {
    return (text.length / 4).ceil();
  }

  // Get current session stats
  Map<String, int> getSessionStats() {
    return {
      'requestTokens': _sessionRequestTokens,
      'responseTokens': _sessionResponseTokens,
      'totalTokens': _sessionRequestTokens + _sessionResponseTokens,
      'requests': _sessionRequests,
    };
  }

  // Get all-time stats
  Future<Map<String, int>> getAllTimeStats() async {
    final prefs = await SharedPreferences.getInstance();
    final totalRequestTokens = prefs.getInt(_requestTokensKey) ?? 0;
    final totalResponseTokens = prefs.getInt(_responseTokensKey) ?? 0;
    final totalRequests = prefs.getInt(_totalRequestsKey) ?? 0;
    
    return {
      'requestTokens': totalRequestTokens,
      'responseTokens': totalResponseTokens,
      'totalTokens': totalRequestTokens + totalResponseTokens,
      'requests': totalRequests,
    };
  }

  // Save tokens to persistent storage
  Future<void> _saveTokensToStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final currentRequestTokens = prefs.getInt(_requestTokensKey) ?? 0;
    final currentResponseTokens = prefs.getInt(_responseTokensKey) ?? 0;
    final currentRequests = prefs.getInt(_totalRequestsKey) ?? 0;
    
    await prefs.setInt(_requestTokensKey, currentRequestTokens + _sessionRequestTokens);
    await prefs.setInt(_responseTokensKey, currentResponseTokens + _sessionResponseTokens);
    await prefs.setInt(_totalRequestsKey, currentRequests + _sessionRequests);
    
    // Reset session counters after saving
    _sessionRequestTokens = 0;
    _sessionResponseTokens = 0;
    _sessionRequests = 0;
  }

  // Clear all token data
  Future<void> clearAllStats() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_requestTokensKey);
    await prefs.remove(_responseTokensKey);
    await prefs.remove(_totalRequestsKey);
    
    _sessionRequestTokens = 0;
    _sessionResponseTokens = 0;
    _sessionRequests = 0;
  }

  // Calculate estimated cost (based on Gemini pricing)
  double calculateEstimatedCost(int totalTokens) {
    // Gemini 2.0 Flash pricing: roughly $0.075 per 1M tokens
    // This is an approximation - actual pricing may vary
    return (totalTokens / 1000000) * 0.075;
  }
}
