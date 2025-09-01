import 'package:any_logger/any_logger.dart';
import 'package:any_logger_json_http/any_logger_json_http.dart';

/// Example configurations for JSON HTTP appender
///
/// These examples demonstrate various configuration options
/// without actually sending HTTP requests.
void main() async {
  // Ensure the JSON_HTTP appender is registered
  AnyLoggerJsonHttpExtension.register();

  print('JSON HTTP Appender Configuration Examples\n');
  print('=' * 50);

  // Example 1: Basic configuration
  example1_basicConfig();

  // Example 2: Authentication examples
  example2_authentication();

  // Example 3: Advanced configuration
  example3_advanced();

  // Example 4: Using the builder pattern
  await example4_builder();

  // Example 5: Integration with LoggerFactory
  await example5_loggerFactory();

  print('\n' + '=' * 50);
  print('Examples completed (no actual HTTP calls made)');
}

/// Example 1: Basic JSON HTTP configuration
void example1_basicConfig() {
  print('\n### Example 1: Basic Configuration ###\n');

  final config = {
    'type': 'JSON_HTTP',
    'url': 'https://log-collector.example.com/logs',
    'level': 'INFO',
    'batchSize': 100,
    'batchIntervalSeconds': 60,
  };

  print('Basic config:');
  config.forEach((key, value) => print('  $key: $value'));

  // Alternative field names (for compatibility)
  final altConfig = {
    'type': 'JSON_HTTP',
    'url': 'https://logs.example.com',
    'bufferSize': 50, // Alternative to batchSize
    'flushIntervalSeconds': 30, // Alternative to batchIntervalSeconds
    'enableCompression': true, // Alternative to compressBatch
  };

  print('\nAlternative field names:');
  altConfig.forEach((key, value) => print('  $key: $value'));
}

/// Example 2: Authentication configurations
void example2_authentication() {
  print('\n### Example 2: Authentication ###\n');

  // Bearer token authentication
  final bearerConfig = {
    'type': 'JSON_HTTP',
    'url': 'https://api.example.com/logs',
    'authToken': 'sk-1234567890abcdef',
    'authType': 'Bearer',
    'level': 'WARN',
  };

  print('Bearer token auth:');
  bearerConfig.forEach((key, value) {
    if (key == 'authToken') {
      print('  $key: ${value.toString().substring(0, 7)}...');
    } else {
      print('  $key: $value');
    }
  });

  // Basic authentication
  final basicAuthConfig = {
    'type': 'JSON_HTTP',
    'url': 'https://logs.example.com',
    'username': 'log_user',
    'password': 'secure_password',
    'level': 'ERROR',
  };

  print('\nBasic auth:');
  basicAuthConfig.forEach((key, value) {
    if (key == 'password') {
      print('  $key: ******');
    } else {
      print('  $key: $value');
    }
  });
}

/// Example 3: Advanced configuration with custom headers
void example3_advanced() {
  print('\n### Example 3: Advanced Configuration ###\n');

  final advancedConfig = {
    'type': 'JSON_HTTP',
    'url': 'https://enterprise.logging.com',
    'endpointPath': 'v2/ingest',
    'level': 'DEBUG',
    'headers': {
      'X-Application-Id': 'my-app-123',
      'X-Environment': 'production',
      'X-Region': 'us-west-2',
    },
    'batchSize': 200,
    'batchIntervalSeconds': 15,
    'maxRetries': 5,
    'retryDelaySeconds': 2,
    'exponentialBackoff': true,
    'includeMetadata': true,
    'includeStackTrace': true,
    'compressBatch': true,
    'timeoutSeconds': 10,
  };

  print('Advanced configuration:');
  advancedConfig.forEach((key, value) {
    if (value is Map) {
      print('  $key:');
      value.forEach((k, v) => print('    $k: $v'));
    } else {
      print('  $key: $value');
    }
  });
}

/// Example 4: Using the builder pattern
Future<void> example4_builder() async {
  print('\n### Example 4: Builder Pattern ###\n');

  // Create appender using builder (in test mode)
  final appender = await jsonHttpAppenderBuilder('https://logs.example.com')
      .withLevel(Level.ERROR)
      .withBearerToken('sk-test-token')
      .withBatchSize(150)
      .withBatchIntervalSeconds(20)
      .withHeaders({
        'X-Service': 'user-service',
        'X-Version': '2.1.0',
      })
      .withStackTraces(true)
      .withMetadata(true)
      .withExponentialBackoff(true)
      .withMaxRetries(3)
      .build(test: true);

  print('Built appender with:');
  print('  URL: ${appender.url}');
  print('  Level: ${appender.level}');
  print('  Batch size: ${appender.batchSize}');
  print('  Batch interval: ${appender.batchInterval}');
  print('  Headers: ${appender.headers}');
  print('  Auth type: ${appender.authType}');

  // Using presets
  final logstashAppender =
      await jsonHttpAppenderBuilder('https://logstash.example.com')
          .withLogstashPreset()
          .build(test: true);

  print('\nLogstash preset appender:');
  print('  Batch size: ${logstashAppender.batchSize}');
  print('  Include metadata: ${logstashAppender.includeMetadata}');
  print('  Include stack traces: ${logstashAppender.includeStackTrace}');

  await appender.dispose();
  await logstashAppender.dispose();
}

/// Example 5: Integration with LoggerFactory
Future<void> example5_loggerFactory() async {
  print('\n### Example 5: LoggerFactory Integration ###\n');

  // Configuration-based setup
  final config = {
    'appenders': [
      {
        'type': 'CONSOLE',
        'level': 'INFO',
        'format': '[%l] %m',
      },
      {
        'type': 'JSON_HTTP',
        'url': 'https://central-logging.example.com',
        'authToken': 'api-key-12345',
        'level': 'WARN',
        'batchSize': 100,
        'batchIntervalSeconds': 30,
      }
    ]
  };

  print('LoggerFactory configuration:');
  final appenders = config['appenders'] as List<Map<String, dynamic>>;
  print('  Appenders: ${appenders.length}');
  for (var i = 0; i < appenders.length; i++) {
    final appender = appenders[i];
    print(
        '    ${i + 1}. Type: ${appender['type']}, Level: ${appender['level']}');
  }

  // Initialize in test mode to avoid actual HTTP connections
  await LoggerFactory.init(config, test: true);

  // Get the logger and check appenders
  final logger = LoggerFactory.getRootLogger();
  print('\nLogger configured with ${logger.appenders.length} appenders:');
  for (var appender in logger.appenders) {
    print('  - ${appender.getType()} (Level: ${appender.level})');
  }

  // Clean up
  await LoggerFactory.dispose();

  // Builder-based setup
  print('\nUsing LoggerBuilder:');
  await LoggerFactory.builder()
      .replaceAll()
      .console(level: Level.INFO)
      .jsonHttp(
        url: 'https://logs.example.com',
        level: Level.ERROR,
        authToken: 'token-xyz',
        batchSize: 50,
      )
      .build(test: true);

  final logger2 = LoggerFactory.getRootLogger();
  print('Builder created ${logger2.appenders.length} appenders');

  await LoggerFactory.dispose();
}
