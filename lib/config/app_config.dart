class AppConfig {
  // API Configuration
  static const String apiBaseUrl = 'http://192.168.1.7:8000';
  static const int apiTimeout = 30000; // 30 seconds

  // App Settings
  static const String appName = 'EOReporter';
  static const String appVersion = '1.0.0';
  
  // Storage Configuration
  static const String storageDirectory = 'eoreporter';
  static const int maxImageSize = 5 * 1024 * 1024; // 5MB
  
  // Location Configuration
  static const int locationUpdateInterval = 5000; // 5 seconds
  static const double locationAccuracy = 10.0; // meters
  static const bool useFineLocation = true; // Use GPS for precise location
  static const bool enableBackgroundLocation = true; // Allow location updates in background
  static const int backgroundLocationInterval = 15000; // 15 seconds for background updates
  
  // Camera Configuration
  static const int maxImageCount = 10;
  static const int imageQuality = 85;
  
  // Theme Configuration
  static const String primaryColor = '#2196F3';
  static const String secondaryColor = '#FFC107';
  
  // Feature Flags
  static const bool enableLocationTracking = true;
  static const bool enableImageUpload = true;
  static const bool enableOfflineMode = true;
} 