import 'package:any_logger/any_logger.dart';

import 'json_http_appender.dart';

/// A specialized builder for creating and configuring [JsonHttpAppender] instances.
///
/// This builder provides a fluent API specifically tailored for JSON HTTP appenders,
/// with all relevant configuration options exposed.
///
/// ### Example Usage:
///
/// ```dart
/// // Simple JSON HTTP appender
/// final appender = await jsonHttpAppenderBuilder('https://logs.example.com')
///     .withLevel(Level.ERROR)
///     .withBatchSize(100)
///     .build();
///
/// // With authentication
/// final authAppender = await jsonHttpAppenderBuilder('https://api.example.com')
///     .withBearerToken('sk-123456')
///     .withLevel(Level.INFO)
///     .withBatchInterval(Duration(seconds: 30))
///     .build();
///
/// // With basic auth and custom headers
/// final customAppender = await jsonHttpAppenderBuilder('https://logs.example.com')
///     .withBasicAuth('user', 'pass')
///     .withHeaders({'X-App-Id': 'myapp'})
///     .withCompression(true)
///     .build();
/// ```

/// Convenience factory function for creating a JsonHttpAppenderBuilder.
JsonHttpAppenderBuilder jsonHttpAppenderBuilder(String url) =>
    JsonHttpAppenderBuilder(url);

class JsonHttpAppenderBuilder {
  final Map<String, dynamic> _config = {
    'type': JsonHttpAppender.appenderName,
  };

  /// Creates a new JsonHttpAppenderBuilder with the required URL.
  JsonHttpAppenderBuilder(String url) {
    _config['url'] = url;
  }

  // --- Common Appender Properties ---

  /// Sets the logging [Level] for this appender.
  JsonHttpAppenderBuilder withLevel(Level level) {
    _config['level'] = level.name;
    return this;
  }

  /// Sets the log message format pattern.
  JsonHttpAppenderBuilder withFormat(String format) {
    _config['format'] = format;
    return this;
  }

  /// Sets the date format pattern for timestamps.
  JsonHttpAppenderBuilder withDateFormat(String dateFormat) {
    _config['dateFormat'] = dateFormat;
    return this;
  }

  /// Sets whether this appender starts enabled.
  JsonHttpAppenderBuilder withEnabledState(bool enabled) {
    _config['enabled'] = enabled;
    return this;
  }

  // --- HTTP Configuration ---

  /// Sets an optional endpoint path to append to the URL.
  JsonHttpAppenderBuilder withEndpointPath(String path) {
    _config['endpointPath'] = path;
    return this;
  }

  /// Sets custom HTTP headers.
  JsonHttpAppenderBuilder withHeaders(Map<String, String> headers) {
    _config['headers'] = headers;
    return this;
  }

  /// Adds a single header.
  JsonHttpAppenderBuilder withHeader(String key, String value) {
    final headers = _config['headers'] as Map<String, String>? ?? {};
    headers[key] = value;
    _config['headers'] = headers;
    return this;
  }

  /// Sets the HTTP timeout duration.
  JsonHttpAppenderBuilder withTimeout(Duration timeout) {
    _config['timeoutSeconds'] = timeout.inSeconds;
    return this;
  }

  /// Sets the HTTP timeout in seconds.
  JsonHttpAppenderBuilder withTimeoutSeconds(int seconds) {
    _config['timeoutSeconds'] = seconds;
    return this;
  }

  // --- Authentication ---

  /// Sets Bearer token authentication.
  JsonHttpAppenderBuilder withBearerToken(String token) {
    _config['authToken'] = token;
    _config['authType'] = 'Bearer';
    return this;
  }

  /// Sets custom authentication with token and type.
  JsonHttpAppenderBuilder withAuthentication(String token, String type) {
    _config['authToken'] = token;
    _config['authType'] = type;
    return this;
  }

  /// Sets Basic authentication with username and password.
  JsonHttpAppenderBuilder withBasicAuth(String username, String password) {
    _config['username'] = username;
    _config['password'] = password;
    _config['authType'] = 'Basic';
    return this;
  }

  // --- Batching Configuration ---

  /// Sets the batch size (number of logs before sending).
  JsonHttpAppenderBuilder withBatchSize(int size) {
    _config['batchSize'] = size;
    return this;
  }

  /// Sets the batch interval (time before sending partial batch).
  JsonHttpAppenderBuilder withBatchInterval(Duration interval) {
    _config['batchIntervalSeconds'] = interval.inSeconds;
    return this;
  }

  /// Sets the batch interval in seconds.
  JsonHttpAppenderBuilder withBatchIntervalSeconds(int seconds) {
    _config['batchIntervalSeconds'] = seconds;
    return this;
  }

  /// Enables or disables batch compression.
  JsonHttpAppenderBuilder withCompression(bool compress) {
    _config['compressBatch'] = compress;
    return this;
  }

  // --- Retry Configuration ---

  /// Sets the maximum number of retry attempts.
  JsonHttpAppenderBuilder withMaxRetries(int retries) {
    _config['maxRetries'] = retries;
    return this;
  }

  /// Sets the delay between retry attempts.
  JsonHttpAppenderBuilder withRetryDelay(Duration delay) {
    _config['retryDelaySeconds'] = delay.inSeconds;
    return this;
  }

  /// Enables or disables exponential backoff for retries.
  JsonHttpAppenderBuilder withExponentialBackoff(bool enabled) {
    _config['exponentialBackoff'] = enabled;
    return this;
  }

  // --- JSON Options ---

  /// Sets whether to include stack traces in the JSON payload.
  JsonHttpAppenderBuilder withStackTraces(bool include) {
    _config['includeStackTrace'] = include;
    return this;
  }

  /// Sets whether to include metadata (device ID, session ID, etc.) in the JSON payload.
  JsonHttpAppenderBuilder withMetadata(bool include) {
    _config['includeMetadata'] = include;
    return this;
  }

  // --- Preset Configurations ---

  /// Applies settings optimized for Logstash.
  JsonHttpAppenderBuilder withLogstashPreset() {
    _config['headers'] = {
      'Content-Type': 'application/json',
    };
    _config['batchSize'] = 200;
    _config['batchIntervalSeconds'] = 30;
    _config['includeMetadata'] = true;
    _config['includeStackTrace'] = true;
    _config['exponentialBackoff'] = true;
    return this;
  }

  /// Applies settings optimized for high-volume logging.
  JsonHttpAppenderBuilder withHighVolumePreset() {
    _config['batchSize'] = 500;
    _config['batchIntervalSeconds'] = 10;
    _config['includeStackTrace'] = false;
    _config['includeMetadata'] = false;
    _config['compressBatch'] = true;
    _config['maxRetries'] = 1;
    return this;
  }

  /// Applies settings optimized for critical error logging.
  JsonHttpAppenderBuilder withCriticalErrorPreset() {
    _config['level'] = Level.ERROR.name;
    _config['batchSize'] = 10;
    _config['batchIntervalSeconds'] = 5;
    _config['includeStackTrace'] = true;
    _config['includeMetadata'] = true;
    _config['maxRetries'] = 5;
    _config['exponentialBackoff'] = true;
    return this;
  }

  /// Applies settings optimized for development/debugging.
  JsonHttpAppenderBuilder withDevelopmentPreset() {
    _config['level'] = Level.DEBUG.name;
    _config['batchSize'] = 1; // Send immediately
    _config['batchIntervalSeconds'] = 1;
    _config['includeStackTrace'] = true;
    _config['includeMetadata'] = true;
    _config['timeoutSeconds'] = 60;
    return this;
  }

  // --- Build Methods ---

  /// Builds the JSON HTTP appender asynchronously.
  ///
  /// Returns a fully configured [JsonHttpAppender] instance.
  Future<JsonHttpAppender> build({bool test = false, DateTime? date}) async {
    return await JsonHttpAppender.fromConfig(_config, test: test, date: date);
  }

  /// Creates a copy of this builder with the same configuration.
  JsonHttpAppenderBuilder copy() {
    final newBuilder = JsonHttpAppenderBuilder(_config['url']);
    newBuilder._config.addAll(_config);
    return newBuilder;
  }

  /// Gets the current configuration as a Map.
  Map<String, dynamic> getConfig() {
    return Map.unmodifiable(_config);
  }

  @override
  String toString() {
    return 'JsonHttpAppenderBuilder(config: $_config)';
  }
}
