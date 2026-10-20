/// Supply the real factory endpoint at build time. No credentials in source.
abstract final class AppConfig {
  static const aiBaseUrl = String.fromEnvironment('FACTORY_AI_BASE_URL');
}
