import 'package:any_logger/any_logger.dart';

/// Builder extension for JsonHttpAppender
extension JsonHttpLoggerBuilderExtension on LoggerBuilder {
  /// Adds a JSON HTTP appender to the logger configuration.
  LoggerBuilder jsonHttp({
    required String url,
    Level level = Level.INFO,
    String? endpointPath,
    Map<String, String>? headers,
    String? authToken,
    String? authType,
    String? username,
    String? password,
    int batchSize = 100,
    int batchIntervalSeconds = 30,
    int timeoutSeconds = 30,
    int maxRetries = 3,
    bool includeStackTrace = true,
    bool includeMetadata = true,
    bool exponentialBackoff = true,
    String format = Appender.defaultFormat,
    String dateFormat = Appender.defaultDateFormat,
  }) {
    final config = <String, dynamic>{
      'type': 'JSON_HTTP',
      'url': url,
      'level': level.name,
      'format': format,
      'dateFormat': dateFormat,
      'batchSize': batchSize,
      'batchIntervalSeconds': batchIntervalSeconds,
      'timeoutSeconds': timeoutSeconds,
      'maxRetries': maxRetries,
      'includeStackTrace': includeStackTrace,
      'includeMetadata': includeMetadata,
      'exponentialBackoff': exponentialBackoff,
    };

    if (endpointPath != null) config['endpointPath'] = endpointPath;
    if (headers != null) config['headers'] = headers;
    if (authToken != null) {
      config['authToken'] = authToken;
      config['authType'] = authType ?? 'Bearer';
    }
    if (username != null) config['username'] = username;
    if (password != null) config['password'] = password;

    return addAppenderConfig(config);
  }
}
