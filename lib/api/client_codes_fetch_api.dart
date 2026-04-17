import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ClientData {
  final String clientCode;
  final String apiUrl;
  final String clientName;

  ClientData({
    required this.clientCode,
    required this.apiUrl,
    required this.clientName,
  });

  factory ClientData.fromJson(Map<String, dynamic> json) {
    return ClientData(
      clientCode: json['client_code'] ?? '',
      apiUrl: json['api_url'] ?? json['url'] ?? '',
      clientName: json['client_name'] ?? '',
    );
  }
}

Future<List<ClientData>> fetchClientCodes() async {
  try {
    // Primary API endpoint
    final response = await http.get(
      Uri.parse(
        'http://att.easytimeonline.in:8080/easytime_online_client_details/get-clients.php',
      ),
    );

    if (response.statusCode == 200) {
      List<dynamic> jsonData = json.decode(response.body);
      return jsonData
          .map<ClientData>((data) => ClientData.fromJson(data))
          .toList();
    } else {
      throw Exception('Failed to load client codes');
    }
  } catch (e) {
    // Fallback to secondary API endpoint or return empty list
    return [];
  }
}

class ApiService {
  static const String defaultBaseUrl = 'https://att.easytimeonline.in:9095';

  // Normalize base URL: remove trailing slash and ensure scheme
  static String _normalizeBaseUrl(String url) {
    if (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }
    return url;
  }

  // Return list of scheme candidates: prefer https then http
  static List<String> _schemeCandidates(String url) {
    final normalized = _normalizeBaseUrl(url);
    final uri = Uri.parse(normalized);
    final https = uri.replace(scheme: 'https').toString();
    final http = uri.replace(scheme: 'http').toString();
    return [https, http];
  }

  // Get the stored base API URL
  static Future<String> getClientApiUrl() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? baseUrl = prefs.getString('base_api_url');
    return baseUrl ?? defaultBaseUrl;
  }

  // Verify client code and get the API URL
  static Future<Map<String, dynamic>> verifyClientCode(
      String clientCode) async {
    try {
      final candidates = _schemeCandidates(defaultBaseUrl);

      for (final base in candidates) {
        final verifyUrl = '$base/api/verify-client-code';

        try {
          final response = await http
              .post(
                Uri.parse(verifyUrl),
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({'client_code': clientCode}),
              )
              .timeout(const Duration(seconds: 10));

          if (response.statusCode == 200) {
            Map<String, dynamic> data;
            try {
              data = json.decode(response.body);
            } catch (e) {
              return {
                'success': false,
                'message': 'Error parsing server response'
              };
            }

            String baseApiUrl;
            if (data.containsKey('api_url')) {
              baseApiUrl = data['api_url'];
            } else if (data.containsKey('url')) {
              baseApiUrl = data['url'];
            } else {
              baseApiUrl = base;
            }

            // If returned URL lacks scheme, use scheme from the base we used
            if (!baseApiUrl.startsWith('http://') &&
                !baseApiUrl.startsWith('https://')) {
              final scheme = Uri.parse(base).scheme;
              baseApiUrl = '$scheme://$baseApiUrl';
            }

            if (baseApiUrl.endsWith('/')) {
              baseApiUrl = baseApiUrl.substring(0, baseApiUrl.length - 1);
            }

            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('base_api_url', baseApiUrl);

            return {
              'success': true,
              'api_url': baseApiUrl,
              'message': 'Client code verified successfully',
              'response_data': data,
              'url_used': verifyUrl
            };
          } else {
            String errorMessage = 'Invalid client code';
            try {
              Map<String, dynamic> errorData = json.decode(response.body);
              if (errorData.containsKey('message')) {
                errorMessage = errorData['message'];
              } else if (errorData.containsKey('error')) {
                errorMessage = errorData['error'];
              }
            } catch (e) {
              // ignore parse errors
            }

            return {
              'success': false,
              'message': errorMessage,
              'status_code': response.statusCode,
              'url_used': verifyUrl
            };
          }
        } catch (e) {
          // network error for this candidate -> try next scheme
          continue;
        }
      }

      return {
        'success': false,
        'message': 'Connection error: Could not reach API via HTTPS or HTTP'
      };
    } catch (e) {
      return {'success': false, 'message': 'Connection error: ${e.toString()}'};
    }
  }

  // IMPORTANT: This method is kept for compatibility but we recommend using directLogin instead
  static Future<Map<String, dynamic>> login(
      String username, String password) async {
    try {
      final apiUrl = await getClientApiUrl();

      // Forward to directLogin for consistent behavior
      return directLogin(apiUrl, username, password);
    } catch (e) {
      return {
        'success': false,
        'message': 'Error connecting to server: ${e.toString()}',
      };
    }
  }

  // Test direct login with explicit URL
  static Future<Map<String, dynamic>> directLogin(
      String apiUrl, String username, String password) async {
    // Try the full login sequence against HTTPS first, then fallback to HTTP on network errors
    try {
      String cleanUrl = apiUrl;
      if (cleanUrl.endsWith('/')) {
        cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
      }

      final candidates = _schemeCandidates(cleanUrl);

      for (final base in candidates) {
        final loginUrl = '$base/api/login';

        try {
          final Map<String, dynamic> credentials = {
            'username': username,
            'password': password,
          };

          final String jsonBody = jsonEncode(credentials);

          http.Response response;

          // 1) JSON
          try {
            response = await http
                .post(
                  Uri.parse(loginUrl),
                  headers: {
                    'Content-Type': 'application/json',
                    'Accept': 'application/json',
                  },
                  body: jsonBody,
                )
                .timeout(const Duration(seconds: 10));
          } catch (e) {
            // network error for this candidate -> try next scheme
            continue;
          }

          // 2) form data
          if (response.statusCode >= 400) {
            try {
              String formBody =
                  'username=${Uri.encodeComponent(username)}&password=${Uri.encodeComponent(password)}';

              response = await http
                  .post(
                    Uri.parse(loginUrl),
                    headers: {
                      'Content-Type': 'application/x-www-form-urlencoded',
                      'Accept': 'application/json',
                    },
                    body: formBody,
                  )
                  .timeout(const Duration(seconds: 10));
            } catch (e) {
              continue;
            }
          }

          // 3) multipart
          if (response.statusCode >= 400) {
            try {
              var request = http.MultipartRequest('POST', Uri.parse(loginUrl));
              request.fields['username'] = username;
              request.fields['password'] = password;

              var streamedResponse =
                  await request.send().timeout(const Duration(seconds: 10));
              response = await http.Response.fromStream(streamedResponse);
            } catch (e) {
              continue;
            }
          }

          // 4) query params
          if (response.statusCode >= 400) {
            try {
              final queryUrl =
                  '$loginUrl?username=${Uri.encodeComponent(username)}&password=${Uri.encodeComponent(password)}';

              response = await http.post(
                Uri.parse(queryUrl),
                headers: {
                  'Accept': 'application/json',
                },
              ).timeout(const Duration(seconds: 10));
            } catch (e) {
              continue;
            }
          }

          // Parse response
          bool isSuccess = false;
          String message = 'Login failed: Invalid credentials';
          Map<String, dynamic> responseData = {};
          bool isJsonResponse = true;

          try {
            responseData = json.decode(response.body);
          } catch (e) {
            isJsonResponse = false;
            responseData = {'raw_text': response.body};
          }

          if (response.statusCode == 200) {
            if (isJsonResponse) {
              if (responseData.containsKey('success') &&
                  responseData['success'] == true) {
                isSuccess = true;
                message = responseData['message'] ?? 'Login successful';
              } else if (responseData.containsKey('user') ||
                  responseData.containsKey('token') ||
                  responseData.containsKey('userData') ||
                  responseData.containsKey('auth_token')) {
                isSuccess = true;
                message = 'Login successful';
              } else if (responseData.containsKey('status') &&
                  responseData['status'].toString().toLowerCase() ==
                      'success') {
                isSuccess = true;
                message = 'Login successful';
              } else if (responseData.containsKey('error') ||
                  (responseData.containsKey('success') &&
                      responseData['success'] == false)) {
                isSuccess = false;
                message = responseData['message'] ??
                    responseData['error'] ??
                    'Login failed: Invalid credentials';
              } else {
                isSuccess = false;
                message =
                    'Login failed: No authentication confirmation from server';
              }
            } else {
              isSuccess = false;
              message = 'Login failed: Invalid response format from server';
            }
          } else {
            isSuccess = false;
            message =
                'Login failed: Server returned error code ${response.statusCode}';
          }

          return {
            'success': isSuccess,
            'message': message,
            'response_code': response.statusCode,
            'response_body': response.body,
            'response_data': responseData,
            'url_used': loginUrl,
            'request_sent': credentials,
            'scheme_used': base,
          };
        } catch (e) {
          // If anything unexpected happened for this base, try next scheme
          continue;
        }
      }

      return {
        'success': false,
        'message':
            'Error connecting to server: Could not reach server via HTTPS or HTTP',
        'url_used': '$apiUrl/api/login'
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error connecting to server: ${e.toString()}',
        'url_used': '$apiUrl/api/login'
      };
    }
  }

  // Login with PHP API endpoint that has parameter issues
  static Future<Map<String, dynamic>> loginWithPhpApi(
      String apiUrl, String username, String password) async {
    try {
      String cleanUrl = apiUrl;
      if (cleanUrl.endsWith('/')) {
        cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
      }

      final candidates = _schemeCandidates(cleanUrl);

      http.Response? successfulResponse;
      String attemptDescription = '';
      String usedLoginUrl = '';

      for (final base in candidates) {
        final loginUrl = '$base/api/login';
        usedLoginUrl = loginUrl;

        List<Future<http.Response>> loginAttempts = [];

        loginAttempts.add(
          http
              .post(
                Uri.parse(loginUrl),
                headers: {'Content-Type': 'application/x-www-form-urlencoded'},
                body: 'username=$username&password=$password',
              )
              .timeout(const Duration(seconds: 10)),
        );

        loginAttempts.add(
          http.post(
            Uri.parse('$loginUrl?username=$username&password=$password'),
            headers: {'Accept': 'application/json'},
          ).timeout(const Duration(seconds: 10)),
        );

        loginAttempts.add(
          http
              .post(
                Uri.parse(loginUrl),
                headers: {'Content-Type': 'application/x-www-form-urlencoded'},
                body: 'username=$username&amp;password=$password',
              )
              .timeout(const Duration(seconds: 10)),
        );

        loginAttempts.add(
          http.get(
            Uri.parse('$loginUrl?username=$username&password=$password'),
            headers: {'Accept': 'application/json'},
          ).timeout(const Duration(seconds: 10)),
        );

        for (int i = 0; i < loginAttempts.length; i++) {
          try {
            final response = await loginAttempts[i];
            if (response.statusCode == 200) {
              successfulResponse = response;
              switch (i) {
                case 0:
                  attemptDescription = 'Standard form data';
                  break;
                case 1:
                  attemptDescription = 'URL query parameters';
                  break;
                case 2:
                  attemptDescription = 'Malformed parameter name';
                  break;
                case 3:
                  attemptDescription = 'Direct GET request';
                  break;
              }
              break;
            }
          } catch (e) {
            // this attempt failed for the current scheme; continue trying other attempts
            // if all attempts fail for this scheme, next scheme will be tried by outer loop
          }
        }

        if (successfulResponse != null) {
          break;
        }
      }

      if (successfulResponse == null) {
        return {
          'success': false,
          'message': 'All login attempts failed',
          'url_used': usedLoginUrl,
        };
      }

      Map<String, dynamic> responseData = {};
      bool isJsonResponse = true;
      try {
        responseData = json.decode(successfulResponse.body);
      } catch (e) {
        isJsonResponse = false;
        responseData = {'raw_text': successfulResponse.body};
      }

      bool isSuccess = false;
      String message = 'Login failed: Invalid credentials';

      if (isJsonResponse) {
        if (responseData.containsKey('status')) {
          if (responseData['status'] == true ||
              responseData['status'].toString().toLowerCase() == 'true' ||
              responseData['status'].toString().toLowerCase() == 'success') {
            isSuccess = true;
            message = responseData['message'] ?? 'Login successful';
          }
        }

        if (responseData.containsKey('user_data')) {
          isSuccess = true;
          message = 'Login successful';
        }
      }

      return {
        'success': isSuccess,
        'message': message,
        'response_code': successfulResponse.statusCode,
        'response_body': successfulResponse.body,
        'response_data': responseData,
        'url_used': usedLoginUrl,
        'method_used': attemptDescription,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error connecting to server: ${e.toString()}',
        'url_used': '$apiUrl/api/login'
      };
    }
  }

  // Set API URL directly
  static Future<void> setApiUrl(String url) async {
    // Clean URL by removing trailing slash if present
    String cleanUrl = url;
    if (cleanUrl.endsWith('/')) {
      cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('base_api_url', cleanUrl);
  }

  // Set up for local development server
  static Future<void> setupLocalServer(String port) async {
    final localUrl = 'http://127.0.0.1:$port';

    // Save this URL as the base API URL
    await setApiUrl(localUrl);

    // Also save a dummy client code for consistency
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('client_code', 'local_dev');

    return;
  }

  // Check if URL is a local development server
  static bool isLocalDevelopmentServer(String url) {
    return url.contains('127.0.0.1') ||
        url.contains('localhost') ||
        url.contains('10.0.2.2'); // Android emulator localhost
  }

  // Test API connection
  static Future<Map<String, dynamic>> testApiConnection(String apiUrl) async {
    // results will be built per-scheme below

    try {
      // Clean URL by removing trailing slash if present
      String cleanUrl = apiUrl;
      if (cleanUrl.endsWith('/')) {
        cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
      }

      final candidates = _schemeCandidates(cleanUrl);
      Map<String, dynamic>? lastResults;

      for (final base in candidates) {
        Map<String, dynamic> candidate = {};

        // Test base URL connection
        try {
          final baseResponse = await http
              .get(Uri.parse(base))
              .timeout(const Duration(seconds: 5));
          candidate['base_url'] = {
            'status': baseResponse.statusCode,
            'success': baseResponse.statusCode < 400,
            'body': baseResponse.body.length > 1000
                ? '${baseResponse.body.substring(0, 1000)}...'
                : baseResponse.body,
          };
        } catch (e) {
          candidate['base_url'] = {
            'status': 'error',
            'message': e.toString(),
            'success': false,
          };
        }

        // Test login endpoint with HEAD request
        try {
          final loginUrl = '$base/api/login';
          final loginHeadResponse = await http
              .head(Uri.parse(loginUrl))
              .timeout(const Duration(seconds: 5));
          candidate['login_head'] = {
            'status': loginHeadResponse.statusCode,
            'success': loginHeadResponse.statusCode < 400,
          };
        } catch (e) {
          candidate['login_head'] = {
            'status': 'error',
            'message': e.toString(),
            'success': false,
          };
        }

        // Test login endpoint with empty body
        try {
          final loginUrl = '$base/api/login';
          final loginEmptyResponse = await http
              .post(
                Uri.parse(loginUrl),
                headers: {'Content-Type': 'application/json'},
                body: '{}',
              )
              .timeout(const Duration(seconds: 5));
          candidate['login_empty'] = {
            'status': loginEmptyResponse.statusCode,
            'body': loginEmptyResponse.body.length > 1000
                ? '${loginEmptyResponse.body.substring(0, 1000)}...'
                : loginEmptyResponse.body,
            'success': true,
          };
        } catch (e) {
          candidate['login_empty'] = {
            'status': 'error',
            'message': e.toString(),
            'success': false,
          };
        }

        // Test login endpoint with sample credentials
        try {
          final loginUrl = '$base/api/login';
          final loginSampleResponse = await http
              .post(
                Uri.parse(loginUrl),
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode(
                    {'username': 'test_user', 'password': 'test_password'}),
              )
              .timeout(const Duration(seconds: 5));
          candidate['login_sample'] = {
            'status': loginSampleResponse.statusCode,
            'body': loginSampleResponse.body.length > 1000
                ? '${loginSampleResponse.body.substring(0, 1000)}...'
                : loginSampleResponse.body,
            'success': true,
          };
        } catch (e) {
          candidate['login_sample'] = {
            'status': 'error',
            'message': e.toString(),
            'success': false,
          };
        }

        // If both base and login_head are successful, return this candidate's results
        if (candidate['base_url']['success'] == true &&
            candidate['login_head']['success'] == true) {
          candidate['diagnosis'] = {
            'success': true,
            'message':
                'API connection looks good. The login endpoint is accessible.',
          };
          return candidate;
        }

        lastResults = candidate;
      }

      // No candidate was fully successful; derive diagnosis from last attempt
      if (lastResults != null) {
        if (lastResults['base_url'] != null &&
            lastResults['base_url']['success'] == false) {
          lastResults['diagnosis'] = {
            'success': false,
            'message':
                'Cannot connect to API server. Check server address and network connection.',
          };
        } else if (lastResults['login_head'] != null &&
            lastResults['login_head']['success'] == false) {
          lastResults['diagnosis'] = {
            'success': false,
            'message':
                'Cannot find login endpoint. API URL may be incorrect or server misconfigured.',
          };
        } else {
          lastResults['diagnosis'] = {
            'success': false,
            'message': 'Unknown connection issue. Check server logs.',
          };
        }

        return lastResults;
      }

      return {
        'error': 'Unknown',
        'diagnosis': {
          'success': false,
          'message': 'API testing failed: Unknown error',
        }
      };
    } catch (e) {
      return {
        'error': e.toString(),
        'diagnosis': {
          'success': false,
          'message': 'API testing failed: ${e.toString()}',
        }
      };
    }
  }
}
