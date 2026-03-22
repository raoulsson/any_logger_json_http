import 'package:any_logger/any_logger.dart';

import '../any_logger_json_http.dart';

/// Extension methods for adding JsonHttpAppender to presets
extension JsonHttpPresets on LoggerPresets {
  /// Production preset with JSON HTTP logging to a central server
  static Map<String, dynamic> productionWithJsonHttp({
    required String url,
    String? authToken,
    String? appVersion,
  }) {
    return {
      'appenders': [
        {
          'type': 'CONSOLE',
          'format': '[%sid][%l] %m',
          'level': 'WARN',
          'dateFormat': 'HH:mm:ss',
        },
        {
          'type': JsonHttpAppender.appenderName,
          'url': url,
          'authToken': authToken,
          'authType': 'Bearer',
          'level': 'INFO',
          'batchSize': 100,
          'batchIntervalSeconds': 60,
          'includeMetadata': true,
          'includeStackTrace': true,
          'maxRetries': 3,
          'exponentialBackoff': true,
        }
      ]
    };
  }

  /// Development preset with JSON HTTP for remote debugging
  static Map<String, dynamic> developmentWithJsonHttp({
    required String url,
    String? username,
    String? password,
  }) {
    return {
      'appenders': [
        {
          'type': 'CONSOLE',
          'format': '[%d][%l][%c] %m [%f]',
          'level': 'DEBUG',
          'dateFormat': 'HH:mm:ss.SSS',
        },
        {
          'type': JsonHttpAppender.appenderName,
          'url': url,
          'username': username,
          'password': password,
          'level': 'DEBUG',
          'batchSize': 50,
          'batchIntervalSeconds': 10,
          'includeMetadata': true,
          'includeStackTrace': true,
        }
      ]
    };
  }

  /// Mobile app preset with crash reporting via JSON HTTP
  static Map<String, dynamic> mobileWithJsonHttp({
    required String url,
    required String apiKey,
    String? appVersion,
  }) {
    return {
      'appenders': [
        {
          'type': 'CONSOLE',
          'format': '[%l] %m',
          'level': 'ERROR',
          'dateFormat': 'HH:mm:ss',
        },
        {
          'type': 'FILE',
          'format': '[%d][%app][%did][%sid][%l] %m [%f]',
          'level': 'WARN',
          'dateFormat': 'yyyy-MM-dd HH:mm:ss.SSS',
          'filePattern': 'crash',
          'path': 'logs/',
          'rotationCycle': 'DAY',
        },
        {
          'type': JsonHttpAppender.appenderName,
          'url': url,
          'authToken': apiKey,
          'authType': 'Bearer',
          'level': 'ERROR',
          'batchSize': 10,
          'batchIntervalSeconds': 30,
          'includeMetadata': true,
          'includeStackTrace': true,
          'maxRetries': 5,
          'exponentialBackoff': true,
        }
      ]
    };
  }
}
