import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'exceptions.dart';

class Request {
  static final Request _instance = Request._internal();
  final Logger _logger = Logger();
  final String _baseUrl = "https://api.example.com";
  String? _authToken;
  Map<String, String> defaultHeaders = {}; // 全局默认请求头

  Request._internal();

  factory Request() {
    return _instance;
  }

  void setAuthToken(String token) {
    _authToken = token;
  }

  void setDefaultHeaders(Map<String, String> headers) {
    defaultHeaders = headers;
  }

  Map<String, String> _addAuthorizationHeaders(Map<String, String>? headers) {
    final modifiedHeaders = {...defaultHeaders, ...(headers ?? {})};
    if (_authToken != null) {
      modifiedHeaders['Authorization'] = 'Bearer $_authToken';
    }
    return modifiedHeaders;
  }

  Future<dynamic> get(String path,
      {Map<String, String>? headers,
      Duration? timeoutDuration,
      Duration? cacheDuration}) async {
    final cacheKey = path;
    final prefs = await SharedPreferences.getInstance();

    if (cacheDuration != null) {
      final cachedData = prefs.getString(cacheKey);
      final cachedTime = prefs.getInt('${cacheKey}_time');
      if (cachedData != null && cachedTime != null) {
        final now = DateTime.now().millisecondsSinceEpoch;
        if (now - cachedTime <= cacheDuration.inMilliseconds) {
          _logger.i('使用缓存数据: $cachedData');
          return jsonDecode(cachedData);
        }
      }
    }

    try {
      final url = Uri.parse('$_baseUrl/$path');
      final modifiedHeaders = _addAuthorizationHeaders(headers);
      _logger.i('GET请求: $url');
      final response = await http
          .get(url, headers: modifiedHeaders)
          .timeout(timeoutDuration ?? const Duration(seconds: 10));

      final result = _handleResponse(response);

      if (cacheDuration != null) {
        prefs.setString(cacheKey, response.body);
        prefs.setInt('${cacheKey}_time', DateTime.now().millisecondsSinceEpoch);
        _logger.i('缓存数据: ${response.body}');
      }

      return result;
    } on TimeoutException {
      throw TimeoutException('请求超时');
    } catch (e) {
      _logger.e('GET请求错误: $e');
      throw Exception('请求失败: $e');
    }
  }

  Future<dynamic> post(String path,
      {Map<String, String>? headers, dynamic body}) async {
    try {
      final url = Uri.parse('$_baseUrl/$path');
      final modifiedHeaders = _addAuthorizationHeaders(headers);
      _logger.i('POST请求: $url');
      final response = await http
          .post(url, headers: modifiedHeaders, body: jsonEncode(body))
          .timeout(const Duration(seconds: 10));

      return _handleResponse(response);
    } on TimeoutException {
      throw TimeoutException('请求超时');
    } catch (e) {
      _logger.e('POST请求错误: $e');
      throw Exception('请求失败: $e');
    }
  }

  dynamic _handleResponse(http.Response response) {
    _logger.i('响应状态码: ${response.statusCode}');
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body);
    } else if (response.statusCode >= 500) {
      throw ServerException('服务器内部错误: ${response.statusCode}');
    } else {
      throw InvalidResponseException(
          '无效响应: ${response.statusCode} - ${response.body}');
    }
  }
}
