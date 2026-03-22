import 'dart:convert';

import 'package:any_logger/any_logger.dart';
import 'package:any_logger_json_http/any_logger_json_http.dart';
import 'package:test/test.dart';

void main() {
  // Ensure the JSON_HTTP appender is registered before all tests
  setUpAll(() {
    AnyLoggerJsonHttpExtension.register();
  });

  group('JsonHttpAppender Configuration', () {
    tearDown(() async {
      await LoggerFactory.dispose();
    });

    test('should create appender from config', () async {
      final config = {
        'type': 'JSON_HTTP',
        'url': 'https://test.example.com',
        'level': 'INFO',
        'batchSize': 100,
        'batchIntervalSeconds': 30,
      };

      final appender = await JsonHttpAppender.fromConfig(config, test: true);

      expect(appender.getType(), equals('JSON_HTTP'));
      expect(appender.url, equals('https://test.example.com'));
      expect(appender.level, equals(Level.INFO));
      expect(appender.batchSize, equals(100));
      expect(appender.batchInterval, equals(Duration(seconds: 30)));
    });

    test('should handle alternative config field names', () async {
      final config = {
        'type': 'JSON_HTTP',
        'url': 'https://test.example.com',
        'bufferSize': 50, // Alternative to batchSize
        'flushIntervalSeconds': 10, // Alternative to batchIntervalSeconds
        'enableCompression': true, // Alternative to compressBatch
      };

      final appender = await JsonHttpAppender.fromConfig(config, test: true);

      expect(appender.batchSize, equals(50));
      expect(appender.batchInterval, equals(Duration(seconds: 10)));
      expect(appender.compressBatch, equals(true));
    });

    test('should configure authentication correctly', () async {
      // Bearer token auth
      final bearerConfig = {
        'type': 'JSON_HTTP',
        'url': 'https://api.example.com',
        'authToken': 'sk-123456',
        'authType': 'Bearer',
      };

      final bearerAppender = await JsonHttpAppender.fromConfig(bearerConfig, test: true);
      expect(bearerAppender.authToken, equals('sk-123456'));
      expect(bearerAppender.authType, equals('Bearer'));
      // Headers are now set in initialize() even in test mode
      expect(bearerAppender.headers['Authorization'], equals('Bearer sk-123456'));

      // Basic auth
      final basicConfig = {
        'type': 'JSON_HTTP',
        'url': 'https://api.example.com',
        'username': 'user',
        'password': 'pass',
      };

      final basicAppender = await JsonHttpAppender.fromConfig(basicConfig, test: true);
      expect(basicAppender.username, equals('user'));
      expect(basicAppender.password, equals('pass'));
      expect(basicAppender.authType, equals('Basic'));

      final expectedBasicAuth = 'Basic ${base64Encode(utf8.encode('user:pass'))}';
      expect(basicAppender.headers['Authorization'], equals(expectedBasicAuth));
    });

    test('should set custom headers', () async {
      final config = {
        'type': 'JSON_HTTP',
        'url': 'https://api.example.com',
        'headers': {
          'X-Application-Id': 'myapp',
          'X-Environment': 'production',
        },
      };

      final appender = await JsonHttpAppender.fromConfig(config, test: true);
      expect(appender.headers['X-Application-Id'], equals('myapp'));
      expect(appender.headers['X-Environment'], equals('production'));
      // Content-Type is set in _setupAuthHeaders()
      expect(appender.headers['Content-Type'], equals('application/json'));
    });

    test('should throw on missing required fields', () {
      final config = {
        'type': 'JSON_HTTP',
        // Missing 'url'
      };

      expect(
        () async => await JsonHttpAppender.fromConfig(config),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('should throw for synchronous factory', () {
      final config = {
        'type': 'JSON_HTTP',
        'url': 'https://test.example.com',
      };

      expect(
        () => JsonHttpAppender.fromConfigSync(config),
        throwsA(isA<UnsupportedError>()),
      );
    });
  });

  group('JsonHttpAppender Batching', () {
    late JsonHttpAppender appender;

    tearDown(() async {
      await appender.dispose();
      await LoggerFactory.dispose();
    });

    test('should batch logs until batch size reached', () async {
      appender = await JsonHttpAppender.fromConfig({
        'url': 'https://test.example.com',
        'batchSize': 3,
        'batchIntervalSeconds': 60,
      }, test: true);

      final contextInfo = LoggerStackTrace.from(StackTrace.current);

      // Add logs but don't reach batch size
      appender.append(LogRecord(Level.INFO, 'Message 1', null, contextInfo));
      appender.append(LogRecord(Level.INFO, 'Message 2', null, contextInfo));

      // Buffer should have 2 items
      expect(appender.getStatistics()['bufferSize'], equals(2));

      // Add one more to trigger batch
      appender.append(LogRecord(Level.INFO, 'Message 3', null, contextInfo));

      // In test mode, buffer is cleared after batch
      expect(appender.getStatistics()['bufferSize'], equals(0));
    });

    test('should send immediately for error levels', () async {
      appender = await JsonHttpAppender.fromConfig({
        'url': 'https://test.example.com',
        'batchSize': 100,
      }, test: true);

      final contextInfo = LoggerStackTrace.from(StackTrace.current);

      // Add 10 error messages
      for (int i = 0; i < 10; i++) {
        appender.append(LogRecord(Level.ERROR, 'Error $i', null, contextInfo));
      }

      // Should send immediately when buffer reaches 10 for errors
      expect(appender.getStatistics()['bufferSize'], equals(0));
    });

    test('should flush on dispose', () async {
      appender = await JsonHttpAppender.fromConfig({
        'url': 'https://test.example.com',
        'batchSize': 100,
      }, test: true);

      final contextInfo = LoggerStackTrace.from(StackTrace.current);

      // Add some logs
      appender.append(LogRecord(Level.INFO, 'Message 1', null, contextInfo));
      appender.append(LogRecord(Level.INFO, 'Message 2', null, contextInfo));

      expect(appender.getStatistics()['bufferSize'], equals(2));

      // Dispose should flush
      await appender.dispose();
      expect(appender.getStatistics()['bufferSize'], equals(0));
    });
  });

  group('JsonHttpAppender JSON Formatting', () {
    test('should exclude stack trace when disabled', () async {
      final appender = await JsonHttpAppender.fromConfig({
        'url': 'https://test.example.com',
        'includeStackTrace': false,
      }, test: true);

      expect(appender.includeStackTrace, equals(false));

      await appender.dispose();
    });

    test('should exclude metadata when disabled', () async {
      final appender = await JsonHttpAppender.fromConfig({
        'url': 'https://test.example.com',
        'includeMetadata': false,
      }, test: true);

      expect(appender.includeMetadata, equals(false));

      await appender.dispose();
    });

    test('should track statistics correctly', () async {
      final appender = await JsonHttpAppender.fromConfig({
        'url': 'https://test.example.com',
        'batchSize': 100,
      }, test: true);

      final stats = appender.getStatistics();
      expect(stats['successfulSends'], equals(0));
      expect(stats['failedSends'], equals(0));
      expect(stats['bufferSize'], equals(0));
      expect(stats['lastSendTime'], isNull);

      // Add some logs and trigger send
      final contextInfo = LoggerStackTrace.from(StackTrace.current);
      for (int i = 0; i < 100; i++) {
        appender.append(LogRecord(Level.INFO, 'Message $i', null, contextInfo));
      }

      // After batch is sent (in test mode)
      final statsAfter = appender.getStatistics();
      expect(statsAfter['successfulSends'], equals(1));
      expect(statsAfter['bufferSize'], equals(0));
      expect(statsAfter['lastSendTime'], isNotNull);

      await appender.dispose();
    });
  });

  group('JsonHttpAppenderBuilder', () {
    tearDown(() async {
      await LoggerFactory.dispose();
    });

    test('should build with basic configuration', () async {
      final appender = await jsonHttpAppenderBuilder('https://test.example.com')
          .withLevel(Level.WARN)
          .withBatchSize(50)
          .build(test: true);

      expect(appender.url, equals('https://test.example.com'));
      expect(appender.level, equals(Level.WARN));
      expect(appender.batchSize, equals(50));

      await appender.dispose();
    });

    test('should build with authentication', () async {
      final bearerAppender =
          await jsonHttpAppenderBuilder('https://api.example.com').withBearerToken('sk-123456').build(test: true);

      expect(bearerAppender.authToken, equals('sk-123456'));
      expect(bearerAppender.authType, equals('Bearer'));

      final basicAppender =
          await jsonHttpAppenderBuilder('https://api.example.com').withBasicAuth('user', 'pass').build(test: true);

      expect(basicAppender.username, equals('user'));
      expect(basicAppender.password, equals('pass'));

      await bearerAppender.dispose();
      await basicAppender.dispose();
    });

    test('should apply presets correctly', () async {
      final logstashAppender =
          await jsonHttpAppenderBuilder('https://logstash.example.com').withLogstashPreset().build(test: true);

      expect(logstashAppender.batchSize, equals(200));
      expect(logstashAppender.batchInterval, equals(Duration(seconds: 30)));
      expect(logstashAppender.includeMetadata, equals(true));
      expect(logstashAppender.includeStackTrace, equals(true));

      final highVolumeAppender =
          await jsonHttpAppenderBuilder('https://high-volume.example.com').withHighVolumePreset().build(test: true);

      expect(highVolumeAppender.batchSize, equals(500));
      expect(highVolumeAppender.includeStackTrace, equals(false));
      expect(highVolumeAppender.includeMetadata, equals(false));

      await logstashAppender.dispose();
      await highVolumeAppender.dispose();
    });

    test('should add headers correctly', () async {
      final appender = await jsonHttpAppenderBuilder('https://api.example.com')
          .withHeaders({'X-App': 'MyApp'})
          .withHeader('X-Version', '1.0.0')
          .build(test: true);

      expect(appender.headers['X-App'], equals('MyApp'));
      expect(appender.headers['X-Version'], equals('1.0.0'));

      await appender.dispose();
    });
  });

  group('JsonHttpAppender Integration', () {
    tearDown(() async {
      await LoggerFactory.dispose();
    });

    test('should register with AppenderRegistry', () async {
      // The registration happens in setUpAll()
      expect(AppenderRegistry.instance.isRegistered('JSON_HTTP'), isTrue);
    });

    test('should work with LoggerFactory.init', () async {
      final config = {
        'appenders': [
          {
            'type': 'CONSOLE',
            'level': 'INFO',
          },
          {
            'type': 'JSON_HTTP',
            'url': 'https://logs.example.com',
            'level': 'ERROR',
            'batchSize': 50,
          },
        ],
      };

      await LoggerFactory.init(config, test: true);
      final logger = LoggerFactory.getRootLogger();

      expect(logger.appenders.length, equals(2));
      expect(logger.appenders[1].getType(), equals('JSON_HTTP'));
    });

    test('should work with LoggerBuilder extension', () async {
      await LoggerFactory.builder()
          .replaceAll()
          .console(level: Level.INFO)
          .jsonHttp(
            url: 'https://api.example.com',
            level: Level.ERROR,
            authToken: 'test-token',
            batchSize: 100,
          )
          .build(test: true);

      final logger = LoggerFactory.getRootLogger();
      expect(logger.appenders.length, equals(2));

      final jsonAppender = logger.appenders[1] as JsonHttpAppender;
      expect(jsonAppender.getType(), equals('JSON_HTTP'));
      expect(jsonAppender.url, equals('https://api.example.com'));
      expect(jsonAppender.authToken, equals('test-token'));
      expect(jsonAppender.batchSize, equals(100));
    });

    test('should handle deep copy correctly', () async {
      final original = await JsonHttpAppender.fromConfig({
        'url': 'https://test.example.com',
        'authToken': 'token123',
        'batchSize': 75,
        'headers': {'X-Test': 'value'},
      }, test: true);

      final copy = original.createDeepCopy() as JsonHttpAppender;

      expect(copy.url, equals(original.url));
      expect(copy.authToken, equals(original.authToken));
      expect(copy.batchSize, equals(original.batchSize));
      expect(copy.headers['X-Test'], equals('value'));
      expect(identical(copy, original), isFalse);
      expect(identical(copy.headers, original.headers), isFalse);

      await original.dispose();
      await copy.dispose();
    });

    test('should respect enabled state', () async {
      final appender = await JsonHttpAppender.fromConfig({
        'url': 'https://test.example.com',
        'enabled': false,
      }, test: true);

      expect(appender.enabled, isFalse);

      final contextInfo = LoggerStackTrace.from(StackTrace.current);
      appender.append(LogRecord(Level.INFO, 'Test', null, contextInfo));

      // Should not add to buffer when disabled
      expect(appender.getStatistics()['bufferSize'], equals(0));

      await appender.dispose();
    });
  });
}
