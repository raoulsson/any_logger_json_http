library any_logger_json_http;

import 'package:any_logger/any_logger.dart';

// Import the implementation files
import 'src/json_http_appender.dart';

// Export public APIs
export 'src/json_http_appender.dart';
export 'src/json_http_appender_builder.dart';
export 'src/json_http_logger_builder_extension.dart';
export 'src/json_http_presets_extension.dart';

/// Extension initialization for JSON HTTP appender.
///
/// This registers the JSON_HTTP appender type with the AnyLogger registry,
/// allowing it to be used in configuration files and builders.
class AnyLoggerJsonHttpExtension {
  static bool _registered = false;

  /// Registers the JSON HTTP appender with the AnyLogger registry.
  ///
  /// Clients have to actually call this before initializing the LoggerFactory
  /// as Dart will "optimize away" any code that in other languages executes on
  /// loading through importing the class file.
  ///
  /// Call: AnyLoggerJsonHttpExtension.register();
  static void register() {
    if (_registered) return;

    AppenderRegistry.instance.register(JsonHttpAppender.appenderName, (config, {test = false, date}) async {
      return await JsonHttpAppender.fromConfig(config, test: test, date: date);
    });

    _registered = true;

    // Log registration if self-debugging is enabled
    Logger.getSelfLogger()?.logDebug('JSON_HTTP appender registered with AppenderRegistry');
  }

  /// Unregisters the JSON HTTP appender (mainly for testing).
  static void unregister() {
    AppenderRegistry.instance.unregister(JsonHttpAppender.appenderName);
    _registered = false;
  }

  /// Check if the appender is registered
  static bool get isRegistered => _registered;
}
