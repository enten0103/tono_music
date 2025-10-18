import 'package:get/get.dart';
import 'package:logger/logger.dart';

class LogService extends GetxService {
  late final Logger _logger;

  Future<LogService> init() async {
    _logger = Logger(
      printer: PrettyPrinter(
        methodCount: 0,
        errorMethodCount: 5,
        lineLength: 80,
        colors: true,
        printEmojis: true,
      ),
    );
    return this;
  }

  void d(String msg, [Object? error, StackTrace? stackTrace]) {
    _logger.d(msg, error, stackTrace);
  }

  void i(String msg, [Object? error, StackTrace? stackTrace]) {
    _logger.i(msg, error, stackTrace);
  }

  void w(String msg, [Object? error, StackTrace? stackTrace]) {
    _logger.w(msg, error, stackTrace);
  }

  void e(String msg, [Object? error, StackTrace? stackTrace]) {
    _logger.e(msg, error, stackTrace);
  }

  void v(String msg, [Object? error, StackTrace? stackTrace]) {
    _logger.v(msg, error, stackTrace);
  }
}
