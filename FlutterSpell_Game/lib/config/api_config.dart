class ApiConfig {
  // Production API URL - can be overridden via environment variable
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );

  // API endpoints
  static const String levelsEndpoint = '/levels';
  static const String usersEndpoint = '/users';
  static const String progressEndpoint = '/progress';
  static const String unlockablesEndpoint = '/unlockables';
  static const String streaksEndpoint = '/streaks';
  static const String challengesEndpoint = '/challenges';
  static const String leaderboardEndpoint = '/leaderboard';

  // Timeouts
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
}
