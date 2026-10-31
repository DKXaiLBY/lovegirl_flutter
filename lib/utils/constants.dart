class AppConstants {
  AppConstants._();

  static const String appName = 'LoveGirl';
  // Only internal QA builds set this define; formal releases use the default.
  static const String baseUrl = String.fromEnvironment('LOVEGIRL_QA_API_URL',
      defaultValue: 'http://47.121.119.191:3001');
  static const String versionName = '4.4.2';
  static const int versionCode = 187;

  // 设计规范
  static const double borderRadius = 14.0;
  static const double borderRadiusLg = 20.0;
  static const double spacing = 8.0;
  static const Duration animDuration = Duration(milliseconds: 300);

  // 存储key
  static const String tokenKey = 'auth_token';
  static const String userKey = 'user_data';
  static const String themeKey = 'theme_mode';
}
