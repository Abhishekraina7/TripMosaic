import 'package:shared_preferences/shared_preferences.dart';

class TokenManager {
  static TokenManager? _instance;
  static SharedPreferences? _prefs;

  TokenManager._();

  static TokenManager getInstance() {
    _instance ??= TokenManager._();
    return _instance!;
  }

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  // Token tracking methods
  Future<void> addRequestTokens(int tokens) async {
    await init();
    final currentTokens = _prefs!.getInt('request_tokens') ?? 0;
    await _prefs!.setInt('request_tokens', currentTokens + tokens);
  }

  Future<void> addResponseTokens(int tokens) async {
    await init();
    final currentTokens = _prefs!.getInt('response_tokens') ?? 0;
    await _prefs!.setInt('response_tokens', currentTokens + tokens);
  }

  Future<int> getRequestTokens() async {
    await init();
    return _prefs!.getInt('request_tokens') ?? 0;
  }

  Future<int> getResponseTokens() async {
    await init();
    return _prefs!.getInt('response_tokens') ?? 0;
  }

  Future<int> getTotalTokens() async {
    await init();
    final requestTokens = await getRequestTokens();
    final responseTokens = await getResponseTokens();
    return requestTokens + responseTokens;
  }

  Future<void> clearTokens() async {
    await init();
    await _prefs!.setInt('request_tokens', 0);
    await _prefs!.setInt('response_tokens', 0);
  }

  // Session tracking
  Future<void> incrementSessionCount() async {
    await init();
    final currentSessions = _prefs!.getInt('session_count') ?? 0;
    await _prefs!.setInt('session_count', currentSessions + 1);
  }

  Future<int> getSessionCount() async {
    await init();
    return _prefs!.getInt('session_count') ?? 0;
  }

  // Cost estimation (approximate)
  Future<double> getEstimatedCost() async {
    await init();
    final totalTokens = await getTotalTokens();
    // Rough estimate: $0.01 per 1000 tokens for Gemini API
    return (totalTokens / 1000) * 0.01;
  }

  // Statistics
  Future<Map<String, dynamic>> getTokenStats() async {
    await init();
    final requestTokens = await getRequestTokens();
    final responseTokens = await getResponseTokens();
    final totalTokens = requestTokens + responseTokens;
    final sessionCount = await getSessionCount();
    final estimatedCost = await getEstimatedCost();

    return {
      'requestTokens': requestTokens,
      'responseTokens': responseTokens,
      'totalTokens': totalTokens,
      'sessionCount': sessionCount,
      'estimatedCost': estimatedCost,
      'averageTokensPerSession': sessionCount > 0 ? (totalTokens / sessionCount).round() : 0,
    };
  }
}
