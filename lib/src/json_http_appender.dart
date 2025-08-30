import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:any_logger/any_logger.dart';
import 'package:http/http.dart' as http;

/// Appender that sends log records as JSON objects over HTTP.
///
/// Features:
/// - Automatic batching of log records
/// - Retry logic with exponential backoff
/// - Configurable headers and authentication
/// - Customizable JSON structure
/// - Compression support
class JsonHttpAppender extends Appender {
  static const String appenderName = 'JSON_HTTP';

  // Connection settings
  late String url;
  Map<String, String> headers = {};
  Duration timeout = Duration(seconds: 30);

  // Authentication
  String? authToken;
  String? authType; // 'Bearer', 'Basic', etc.
  String? username;
  String? password;

  // Batch settings
  final List<LogRecord> _logBuffer = [];
  int batchSize = 100;
  Duration batchInterval = Duration(seconds: 30);
  Timer? _batchTimer;
  bool compressBatch = false;

  // Retry settings
  int maxRetries = 3;
  Duration retryDelay = Duration(seconds: 2);
  bool exponentialBackoff = true;

  // JSON customization
  bool includeStackTrace = true;
  bool includeMetadata = true;
  String? endpointPath; // Optional path to append to URL

  // Statistics
  int _successfulSends = 0;
  int _failedSends = 0;
  DateTime? _lastSendTime;

  // Test mode
  bool test = false;
  http.Client? _httpClient;

  JsonHttpAppender() : super();

  /// Factory constructor for configuration-based creation
  static Future<JsonHttpAppender> fromConfig(Map<String, dynamic> config, {bool test = false, DateTime? date}) async {
    final appender = JsonHttpAppender()
      ..test = test
      ..created = date ?? DateTime.now();

    appender.initializeCommonProperties(config, test: test, date: date);

    // Required fields
    if (!config.containsKey('url')) {
      throw ArgumentError('Missing url argument for JsonHttpAppender');
    }
    appender.url = config['url'];

    // Optional endpoint path
    if (config.containsKey('endpointPath')) {
      appender.endpointPath = config['endpointPath'];
    }

    // Headers
    if (config.containsKey('headers')) {
      final configHeaders = config['headers'];
      if (configHeaders is Map) {
        appender.headers = Map<String, String>.from(configHeaders);
      }
    }

    // Authentication
    if (config.containsKey('authToken')) {
      appender.authToken = config['authToken'];
      appender.authType = config['authType'] ?? 'Bearer';
    } else if (config.containsKey('username') && config.containsKey('password')) {
      appender.username = config['username'];
      appender.password = config['password'];
      appender.authType = 'Basic';
    }

    // Timeout
    if (config.containsKey('timeoutSeconds')) {
      appender.timeout = Duration(seconds: config['timeoutSeconds']);
    }

    // Batch settings (support both naming conventions)
    if (config.containsKey('batchSize')) {
      appender.batchSize = config['batchSize'];
    } else if (config.containsKey('bufferSize')) {
      appender.batchSize = config['bufferSize'];
    }

    if (config.containsKey('batchIntervalSeconds')) {
      appender.batchInterval = Duration(seconds: config['batchIntervalSeconds']);
    } else if (config.containsKey('flushIntervalSeconds')) {
      appender.batchInterval = Duration(seconds: config['flushIntervalSeconds']);
    }

    if (config.containsKey('compressBatch')) {
      appender.compressBatch = config['compressBatch'];
    } else if (config.containsKey('enableCompression')) {
      appender.compressBatch = config['enableCompression'];
    }

    // Retry settings
    if (config.containsKey('maxRetries')) {
      appender.maxRetries = config['maxRetries'];
    }

    if (config.containsKey('retryDelaySeconds')) {
      appender.retryDelay = Duration(seconds: config['retryDelaySeconds']);
    }

    if (config.containsKey('exponentialBackoff')) {
      appender.exponentialBackoff = config['exponentialBackoff'];
    }

    // JSON options
    if (config.containsKey('includeStackTrace')) {
      appender.includeStackTrace = config['includeStackTrace'];
    }

    if (config.containsKey('includeMetadata')) {
      appender.includeMetadata = config['includeMetadata'];
    }

    // Initialize (including setting up headers)
    await appender.initialize();

    return appender;
  }

  /// Synchronous factory - throws since HTTP requires async
  factory JsonHttpAppender.fromConfigSync(Map<String, dynamic> config) {
    throw UnsupportedError('JsonHttpAppender requires async initialization. Use fromConfig() or builder().build()');
  }

  /// Initialize the appender
  Future<void> initialize() async {
    // Setup authentication headers - do this for both test and normal mode
    _setupAuthHeaders();

    if (test) {
      Logger.getSelfLogger()?.logDebug('JsonHttpAppender in test mode - skipping HTTP client and timer initialization');
      return;
    }

    // Setup HTTP client
    _httpClient = http.Client();

    // Start batch timer
    _startBatchTimer();

    Logger.getSelfLogger()?.logDebug('JsonHttpAppender initialized: $this');
  }

  void _setupAuthHeaders() {
    if (authType == 'Bearer' && authToken != null) {
      headers['Authorization'] = 'Bearer $authToken';
    } else if (authType == 'Basic' && username != null && password != null) {
      final credentials = base64Encode(utf8.encode('$username:$password'));
      headers['Authorization'] = 'Basic $credentials';
    }

    // Ensure content type is set
    headers['Content-Type'] ??= 'application/json';
  }

  void _startBatchTimer() {
    _batchTimer?.cancel();
    _batchTimer = Timer.periodic(batchInterval, (_) {
      if (_logBuffer.isNotEmpty) {
        _sendBatch();
      }
    });
    Logger.getSelfLogger()?.logDebug('Batch timer started with interval: $batchInterval');
  }

  @override
  Appender createDeepCopy() {
    JsonHttpAppender copy = JsonHttpAppender();
    copyBasePropertiesTo(copy);

    copy.test = test;
    copy.url = url;
    copy.headers = Map.from(headers);
    copy.timeout = timeout;
    copy.authToken = authToken;
    copy.authType = authType;
    copy.username = username;
    copy.password = password;
    copy.batchSize = batchSize;
    copy.batchInterval = batchInterval;
    copy.compressBatch = compressBatch;
    copy.maxRetries = maxRetries;
    copy.retryDelay = retryDelay;
    copy.exponentialBackoff = exponentialBackoff;
    copy.includeStackTrace = includeStackTrace;
    copy.includeMetadata = includeMetadata;
    copy.endpointPath = endpointPath;

    // Initialize the copy
    if (copy.test) {
      // In test mode, just set up headers
      copy._setupAuthHeaders();
    } else {
      copy._httpClient = http.Client();
      copy._setupAuthHeaders();
      copy._startBatchTimer();
    }

    return copy;
  }

  @override
  void append(LogRecord logRecord) {
    if (!enabled) return;

    logRecord.loggerName ??= getType().toString();

    // Add to buffer
    _logBuffer.add(logRecord);

    // Check if we should send immediately (for critical errors)
    if (logRecord.level.index >= Level.ERROR.index && _logBuffer.length >= 10) {
      _sendBatch();
    }
    // Or if buffer is full
    else if (_logBuffer.length >= batchSize) {
      _sendBatch();
    }
  }

  Future<void> _sendBatch() async {
    if (_logBuffer.isEmpty) return;

    // Copy and clear buffer
    final logs = List<LogRecord>.from(_logBuffer);
    _logBuffer.clear();

    if (test) {
      Logger.getSelfLogger()?.logDebug('Test mode: Would send batch of ${logs.length} logs to $url');
      _successfulSends++;
      _lastSendTime = DateTime.now();
      return;
    }

    try {
      final jsonData = _createJsonPayload(logs);
      final body = jsonEncode(jsonData);

      final success = await _sendWithRetry(body);

      if (success) {
        _successfulSends++;
        _lastSendTime = DateTime.now();
        Logger.getSelfLogger()?.logDebug('Successfully sent ${logs.length} log records to $url');
      } else {
        _failedSends++;
        // Put logs back if send failed (with overflow protection)
        if (_logBuffer.length < batchSize * 2) {
          _logBuffer.insertAll(0, logs);
        } else {
          Logger.getSelfLogger()?.logWarn('Dropping ${logs.length} log records due to buffer overflow');
        }
      }
    } catch (e) {
      _failedSends++;
      Logger.getSelfLogger()?.logError('Failed to send logs: $e');

      // Put logs back if there's room
      if (_logBuffer.length < batchSize * 2) {
        _logBuffer.insertAll(0, logs);
      }
    }
  }

  Map<String, dynamic> _createJsonPayload(List<LogRecord> logs) {
    final payload = <String, dynamic>{
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'count': logs.length,
    };

    if (includeMetadata) {
      payload['metadata'] = {
        'appVersion': LoggerFactory.getAppVersion(),
        'deviceId': LoggerFactory.getDeviceId(),
        'sessionId': LoggerFactory.getSessionId(),
        'hostname': _getHostname(),
      };
    }

    payload['logs'] = logs.map((log) => _logRecordToJson(log)).toList();

    return payload;
  }

  Map<String, dynamic> _logRecordToJson(LogRecord log) {
    final json = <String, dynamic>{
      'timestamp': log.time.toUtc().toIso8601String(),
      'level': log.level.name,
      'levelValue': log.level.value,
      'message': log.message.toString(),
    };

    // Add optional fields if present
    if (log.loggerName != null) json['logger'] = log.loggerName;
    if (log.tag != null) json['tag'] = log.tag;
    if (log.className != null) json['class'] = log.className;
    if (log.methodName != null) json['method'] = log.methodName;
    // if (log.fileName != null) json['file'] = log.fileName;
    if (log.lineNumber != null) json['line'] = log.lineNumber;

    // Error information
    if (log.error != null) {
      json['error'] = {
        'message': log.error.toString(),
        'type': log.error.runtimeType.toString(),
      };
    }

    // Stack trace (if enabled and present)
    if (includeStackTrace && log.stackTrace != null) {
      json['stackTrace'] = log.stackTrace.toString();
    }

    // Add MDC context if available
    final mdcValues = LoggerFactory.getAllMdcValues();
    if (mdcValues.isNotEmpty) {
      json['mdc'] = mdcValues;
    }

    return json;
  }

  Future<bool> _sendWithRetry(String body) async {
    int attempts = 0;
    Duration currentDelay = retryDelay;

    while (attempts <= maxRetries) {
      try {
        final fullUrl = endpointPath != null ? '$url/$endpointPath'.replaceAll('//', '/') : url;

        final response = await _httpClient!
            .post(
              Uri.parse(fullUrl),
              headers: headers,
              body: body,
            )
            .timeout(timeout);

        if (response.statusCode >= 200 && response.statusCode < 300) {
          return true;
        } else if (response.statusCode >= 400 && response.statusCode < 500) {
          // Client error - don't retry
          Logger.getSelfLogger()?.logError('Client error sending logs: ${response.statusCode} ${response.body}');
          return false;
        } else {
          // Server error - retry
          Logger.getSelfLogger()?.logWarn('Server error: ${response.statusCode}, attempt ${attempts + 1}/$maxRetries');
        }
      } on TimeoutException {
        Logger.getSelfLogger()?.logWarn('Timeout sending logs, attempt ${attempts + 1}/$maxRetries');
      } catch (e) {
        Logger.getSelfLogger()?.logWarn('Error sending logs: $e, attempt ${attempts + 1}/$maxRetries');
      }

      attempts++;
      if (attempts <= maxRetries) {
        await Future.delayed(currentDelay);
        if (exponentialBackoff) {
          currentDelay = currentDelay * 2;
        }
      }
    }

    return false;
  }

  String _getHostname() {
    try {
      // This works on most platforms
      return Platform.localHostname;
    } catch (e) {
      return 'unknown';
    }
  }

  @override
  Future<void> flush() async {
    if (_logBuffer.isNotEmpty) {
      await _sendBatch();
    }
  }

  @override
  Future<void> dispose() async {
    _batchTimer?.cancel();
    await flush();
    _httpClient?.close();
    Logger.getSelfLogger()?.logDebug('JsonHttpAppender disposed');
  }

  @override
  String toString() {
    return 'JsonHttpAppender(url: $url, batchSize: $batchSize, '
        'batchInterval: $batchInterval, enabled: $enabled, '
        'stats: {sent: $_successfulSends, failed: $_failedSends})';
  }

  @override
  String getType() {
    return JsonHttpAppender.appenderName;
  }

  /// Get statistics about sent logs
  Map<String, dynamic> getStatistics() {
    return {
      'successfulSends': _successfulSends,
      'failedSends': _failedSends,
      'lastSendTime': _lastSendTime?.toIso8601String(),
      'bufferSize': _logBuffer.length,
    };
  }
}
