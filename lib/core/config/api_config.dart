class ApiConfig {
  ApiConfig._();

  /// Production API used by the ILECO PAY consumer app.
  ///
  /// A different HTTPS API can still be supplied at build time with:
  ///
  /// flutter build apk --release ^
  ///   --dart-define=API_BASE_URL=https://ilecopay.com/ileco_pay/api
  static const String _configuredBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://ilecopay.com/ileco_pay/api',
  );

  /// Current API root used by all services that call [buildUri].
  static String baseUrl = _normalize(_configuredBaseUrl);

  /// Initializes the application API configuration.
  ///
  /// The consumer app now uses its configured hosted HTTPS endpoint directly.
  /// Old device-saved server addresses are intentionally ignored.
  static Future<void> init() async {
    baseUrl = _normalize(_configuredBaseUrl);
  }

  /// Returns the API root currently used by the app.
  static Future<String> getBaseUrl() async {
    return baseUrl;
  }

  /// Updates the API root for the current app process.
  ///
  /// This is kept for compatibility with existing callers, but only secure
  /// HTTPS endpoints are accepted and the value is not persisted on-device.
  static Future<void> setBaseUrl(String url) async {
    baseUrl = _normalize(url);
  }

  /// Restores the configured production API root.
  static Future<void> resetToDefault() async {
    baseUrl = _normalize(_configuredBaseUrl);
  }

  /// Creates a complete API URI from the configured API root.
  static Uri buildUri(
      String endpoint, {
        Map<String, dynamic>? query,
      }) {
    final String cleanEndpoint =
    endpoint.trim().replaceFirst(RegExp(r'^/+'), '');

    if (cleanEndpoint.isEmpty) {
      throw const FormatException(
        'A valid API endpoint is required.',
      );
    }

    final String root = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;

    final Uri uri = Uri.parse('$root/$cleanEndpoint');

    if (query == null || query.isEmpty) {
      return uri;
    }

    final Map<String, String> queryParameters =
    <String, String>{};

    for (final MapEntry<String, dynamic> entry
    in query.entries) {
      final dynamic value = entry.value;

      if (value == null) {
        continue;
      }

      queryParameters[entry.key] = value.toString();
    }

    return uri.replace(
      queryParameters:
      queryParameters.isEmpty ? null : queryParameters,
    );
  }

  /// Returns true when the configured API is a usable HTTPS endpoint.
  static bool get isConfigured {
    final Uri? uri = Uri.tryParse(baseUrl);

    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty) {
      return false;
    }

    final String host = uri.host.toLowerCase();

    return host != 'example.com' &&
        !host.endsWith('.example.com') &&
        host != 'your-domain.com';
  }

  /// Normalizes an API address and enforces HTTPS.
  static String _normalize(String raw) {
    String value = raw
        .trim()
        .replaceAll('\n', '')
        .replaceAll('\r', '')
        .replaceAll(' ', '');

    if (value.isEmpty) {
      throw const FormatException(
        'A valid API address is required.',
      );
    }

    if (!value.startsWith('https://')) {
      if (value.startsWith('http://')) {
        throw const FormatException(
          'ILECO PAY requires a secure HTTPS API address.',
        );
      }

      value = 'https://$value';
    }

    Uri? uri = Uri.tryParse(value);

    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty) {
      throw const FormatException(
        'Invalid secure API address.',
      );
    }

    String path = uri.path.trim();

    while (path.endsWith('/') && path.length > 1) {
      path = path.substring(0, path.length - 1);
    }

    if (path.isEmpty || path == '/') {
      path = '/ileco_pay/api';
    } else if (path == '/ileco_pay') {
      path = '/ileco_pay/api';
    } else if (path == '/api') {
      path = '/ileco_pay/api';
    } else if (!path.endsWith('/api')) {
      path = '$path/api';
    }

    uri = uri.replace(
      path: path,
      query: null,
      fragment: null,
    );

    return uri.toString().replaceFirst(
      RegExp(r'/$'),
      '',
    );
  }
}
