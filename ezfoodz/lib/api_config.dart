/// Central configuration for the EZFOODZ app.
class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: "https://ezfoodz-api-164107786597.asia-south1.run.app",
  );
}
