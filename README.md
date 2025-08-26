# Any Logger JSON HTTP

A JSON HTTP appender extension for [Any Logger](https://pub.dev/packages/any_logger) that enables
sending structured logs to REST APIs, Logstash, centralized logging services, and custom HTTP
endpoints with automatic batching, retry logic, and compression support.

## Features

- **Automatic Batching** - Intelligently batches logs to reduce network overhead
- **Retry Logic** - Configurable retry with exponential backoff for failed sends
- **Multiple Auth Methods** - Supports Bearer tokens, Basic auth, and custom headers
- **Compression Support** - Optional batch compression to reduce bandwidth
- **Flexible Configuration** - Works with config files, builders, or programmatic setup
- **Error Recovery** - Buffers logs during network failures and retries when connection resumes
- **Statistics Tracking** - Monitor successful/failed sends and buffer status

## Installation

```yaml
dependencies:
  any_logger: ^x.y.z  
  any_logger_json_http: ^x.y.z  // See Installing
```

To register the JSON HTTP appender you have to import the library

```dart
import 'package:any_logger/any_logger.dart';
import 'package:any_logger_mysql/any_logger_mysql.dart';
```
and call:

```dart
AnyLoggerJsonHttpExtension.register();
```

## Quick Start

### Simple Setup

```dart
await
LoggerFactory.builder
().console
(
level: Level.INFO)
    .jsonHttp(
url: 'https://logs.example.com/api/logs',
level: Level.WARN,
authToken: 'your-api-key',
)
    .build();

Logger.info('This goes to console only');
Logger.warn('This goes to both console and HTTP endpoint');
Logger
.
error
(
'
Errors are batched and sent efficiently
'
);
```

### With Authentication

```dart
// Bearer token (most common)
await
LoggerFactory.builder
().jsonHttp
(
url: 'https://api.logservice.com',
authToken: 'sk-1234567890',
authType: 'Bearer',
level: Level.ERROR,
)
    .build();

// Basic authentication
await LoggerFactory.builder()
    .jsonHttp(
url: 'https://logs.example.com',
username: 'logger',
password: 'secure_password',
level: Level.INFO
,
)
.
build
(
);
```

## Configuration Options

### Using Builder Pattern

```dart

final appender = await
jsonHttpAppenderBuilder
('https://logs.example.com
'
)
.withLevel(Level.ERROR)
    .withBearerToken('api-key-123')
    .withBatchSize(100)
    .withBatchIntervalSeconds(30)
    .withHeaders({
'X-Application': 'MyApp',
'X-Environment': 'production',
})
    .withStackTraces(true)
    .withMetadata(true)
    .withMaxRetries(5)
    .withExponentialBackoff(true)
.
build
(
);
```

### Using Configuration Map

```dart

final config = {
  'appenders': [
    {
      'type': 'JSON_HTTP',
      'url': 'https://logs.example.com',
      'endpointPath': 'v2/ingest',
      'authToken': 'your-token',
      'authType': 'Bearer',
      'level': 'INFO',
      'batchSize': 100,
      'batchIntervalSeconds': 30,
      'headers': {
        'X-Application-Id': 'myapp',
        'X-Environment': 'production',
      },
      'includeMetadata': true,
      'includeStackTrace': true,
      'maxRetries': 3,
      'exponentialBackoff': true,
      'timeoutSeconds': 10,
    }
  ]
};

await
LoggerFactory.init
(
config
);
```

### Configuration Parameters

| Parameter              | Type   | Default  | Description                              |
|------------------------|--------|----------|------------------------------------------|
| `url`                  | String | Required | Base URL of the logging endpoint         |
| `endpointPath`         | String | null     | Optional path to append to URL           |
| `level`                | Level  | INFO     | Minimum log level to send                |
| `authToken`            | String | null     | Authentication token                     |
| `authType`             | String | 'Bearer' | Type of auth ('Bearer', 'Basic', etc.)   |
| `username`             | String | null     | Username for Basic auth                  |
| `password`             | String | null     | Password for Basic auth                  |
| `batchSize`            | int    | 100      | Number of logs before sending            |
| `batchIntervalSeconds` | int    | 30       | Max seconds before sending partial batch |
| `headers`              | Map    | {}       | Custom HTTP headers                      |
| `includeMetadata`      | bool   | true     | Include device/session/app info          |
| `includeStackTrace`    | bool   | true     | Include stack traces for errors          |
| `maxRetries`           | int    | 3        | Number of retry attempts                 |
| `exponentialBackoff`   | bool   | true     | Use exponential backoff for retries      |
| `timeoutSeconds`       | int    | 30       | HTTP request timeout                     |
| `compressBatch`        | bool   | false    | Compress batched logs                    |

### Alternative Field Names

For compatibility with different configuration formats:

- `bufferSize` → `batchSize`
- `flushIntervalSeconds` → `batchIntervalSeconds`
- `enableCompression` → `compressBatch`

## JSON Payload Structure

The appender sends logs in this format:

```json
{
  "timestamp": "2025-01-20T10:30:45.123Z",
  "count": 3,
  "metadata": {
    "appVersion": "1.2.3",
    "deviceId": "a3f5c8d2",
    "sessionId": "e7b9f1a4",
    "hostname": "server-01"
  },
  "logs": [
    {
      "timestamp": "2025-01-20T10:30:45.100Z",
      "level": "ERROR",
      "levelValue": 40000,
      "message": "Database connection failed",
      "logger": "DatabaseService",
      "tag": "DB",
      "class": "DatabaseService",
      "method": "connect",
      "line": 42,
      "error": {
        "message": "Connection timeout",
        "type": "TimeoutException"
      },
      "stackTrace": "...",
      "mdc": {
        "userId": "user-123",
        "requestId": "req-456"
      }
    }
  ]
}
```

## Presets

### Logstash Integration

```dart

final appender = await
jsonHttpAppenderBuilder
('https://logstash.example.com
'
)
.withLogstashPreset(
) // Optimized for Logstash
.
build
(
);

// Preset configures:
// - batchSize: 200
// - batchIntervalSeconds: 30
// - includeMetadata: true
// - includeStackTrace: true
// - exponentialBackoff: true
```

### High Volume Logging

```dart

final appender = await
jsonHttpAppenderBuilder
('https://logs.example.com
'
)
.withHighVolumePreset(
) // Optimized for high throughput
.
build
(
);

// Preset configures:
// - batchSize: 500
// - batchIntervalSeconds: 10
// - includeStackTrace: false (performance)
// - includeMetadata: false (reduce payload)
// - compressBatch: true
```

### Critical Errors Only

```dart

final appender = await
jsonHttpAppenderBuilder
('https://alerts.example.com
'
)
.withCriticalErrorPreset()
    .withBearerToken('alert-api-key')
    .build
(
);

// Preset configures:
// - level: ERROR
// - batchSize: 10 (send quickly)
// - batchIntervalSeconds: 5
// - includeStackTrace: true
// - maxRetries: 5
```

## Integration Examples

### With Centralized Logging Service

```dart
// Datadog, Loggly, Papertrail, etc.
await
LoggerFactory.builder
().console
().jsonHttp
(
url: 'https://http-intake.logs.datadoghq.com',
endpointPath: 'v1/input',
authToken: process.env['DD_API_KEY'],
headers: {
'DD-EVP-ORIGIN': 'my-app',
'DD-EVP-ORIGIN-VERSION': '1.0.0',
},
level: Level.INFO,
)
    .build(
);
```

### With Custom Backend

```dart
await
LoggerFactory.builder
().jsonHttp
(
url: 'https://api.mycompany.com',
endpointPath: 'logging/v1/ingest',
authToken: await getAuthToken(),
headers: {
'X-Client-Version': '2.1.0',
'X-Platform': Platform.operatingSystem,
},
batchSize: 50,
includeMetadata: true,
)
.
build
(
);
```

### Error Alerting System

```dart
// Send only errors immediately to alerting system
await
LoggerFactory.builder
().file
(
filePattern: 'app', level: Level.DEBUG) // All logs to file
    .jsonHttp(
url: 'https://alerts.example.com/critical',
level: Level.ERROR, // Only errors to HTTP
batchSize: 1, // Send immediately
authToken: 'alert-key',
)
    .build();
```

## Monitoring & Statistics

```dart

final appender = logger.appenders
    .whereType<JsonHttpAppender>()
    .firstOrNull;

if (
appender != null) {
final stats = appender.getStatistics();
print('Successful sends: ${stats['successfulSends']}');
print('Failed sends: ${stats['failedSends']}');
print('Buffer size: ${stats['bufferSize']}');
print('Last send: ${stats['lastSendTime']}');
}
```

## Best Practices

### 1. Choose Appropriate Batch Sizes

- **Low volume**: 50-100 logs per batch
- **High volume**: 200-500 logs per batch
- **Critical errors**: 1-10 for immediate sending

### 2. Set Reasonable Intervals

- **Production**: 30-60 seconds
- **Development**: 5-10 seconds
- **Critical systems**: 1-5 seconds

### 3. Handle Network Failures

```dart
// Configure retry strategy
    .withMaxRetries(5)
    .withExponentialBackoff(true)
    .withTimeoutSeconds(
10
)
```

### 4. Optimize Payload Size

```dart
// For high-volume, non-critical logs
    .withStackTraces(false) // Reduce size
    .withMetadata(false) // Only if not needed
    .withCompression(
true
) // Compress batches
```

### 5. Secure Your Credentials

```dart
// Use environment variables or secure storage
final apiKey = Platform.environment['LOG_API_KEY'];
// Or use a secrets manager
final apiKey = await
SecretManager.getSecret
('log-api-key
'
);
```

## Troubleshooting

### Logs Not Reaching Server

1. **Check network connectivity**
2. **Verify authentication**: Ensure token/credentials are correct
3. **Check URL and endpoint**: Verify the full URL is correct
4. **Enable self-debugging**:

```dart
await
LoggerFactory.builder
().jsonHttp
(
url: 'https://logs.example.com')
    .withSelfDebug(Level.DEBUG
)
.
build
(
);
```

### High Memory Usage

- Reduce `batchSize` to limit buffer memory
- Enable `compressBatch` for large payloads
- Disable `includeStackTrace` if not needed

### Logs Lost During Shutdown

Always flush before app termination:

```dart
// In your app shutdown handler
await
LoggerFactory.flushAll
();
```

## Testing

For unit tests, use test mode to avoid actual HTTP calls:

```dart

final appender = await
jsonHttpAppenderBuilder
('https://test.example.com
'
)
.withLevel(Level.INFO)
    .build(test: true
); // No actual HTTP calls made
```

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Support

- Main Package: [any_logger](https://pub.dev/packages/any_logger)
- Issues: [GitHub Issues](https://github.com/yourusername/any_logger_json_http/issues)
- Examples: See `/example` folder in the package

---

Part of the [Any Logger](https://pub.dev/packages/any_logger) ecosystem.

## 💚 Funding

- 🏅 https://github.com/sponsors/raoulsson
- 🪙 https://www.buymeacoffee.com/raoulsson

---

**Happy Logging! 🎉**