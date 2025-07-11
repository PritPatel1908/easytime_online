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
  static const String defaultBaseUrl = 'http://att.easytimeonline.in:121';

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
      const verifyUrl = '$defaultBaseUrl/api/verify-client-code';

      final response = await http.post(
        Uri.parse(verifyUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'client_code': clientCode}),
      );

      if (response.statusCode == 200) {
        // Try to parse response body
        Map<String, dynamic> data;
        try {
          data = json.decode(response.body);
        } catch (e) {
          return {'success': false, 'message': 'Error parsing server response'};
        }

        // Extract the API URL from the response
        String baseApiUrl;
        if (data.containsKey('api_url')) {
          baseApiUrl = data['api_url'];
        } else if (data.containsKey('url')) {
          baseApiUrl = data['url'];
        } else {
          // If neither field exists, use default
          baseApiUrl = defaultBaseUrl;
        }

        // Remove trailing slash if present
        if (baseApiUrl.endsWith('/')) {
          baseApiUrl = baseApiUrl.substring(0, baseApiUrl.length - 1);
        }

        // Save to shared preferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('base_api_url', baseApiUrl);

        return {
          'success': true,
          'api_url': baseApiUrl,
          'message': 'Client code verified successfully',
          'response_data': data
        };
      } else {
        // Try to parse error message from response if available
        String errorMessage = 'Invalid client code';
        try {
          Map<String, dynamic> errorData = json.decode(response.body);
          if (errorData.containsKey('message')) {
            errorMessage = errorData['message'];
          } else if (errorData.containsKey('error')) {
            errorMessage = errorData['error'];
          }
        } catch (e) {
          // If we can't parse the response, use default message
        }

        return {
          'success': false,
          'message': errorMessage,
          'status_code': response.statusCode
        };
      }
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
    try {
      // Clean URL by removing trailing slash if present
      String cleanUrl = apiUrl;
      if (cleanUrl.endsWith('/')) {
        cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
      }

      // Always use /api/login endpoint for authentication
      final loginUrl = '$cleanUrl/api/login';

      // Create different request body formats to try
      final Map<String, dynamic> credentials = {
        'username': username,
        'password': password,
      };

      // 1. Standard JSON body
      final String jsonBody = jsonEncode(credentials);

      // Try with JSON content type first (most common)
      var response = await http
          .post(
            Uri.parse(loginUrl),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonBody,
          )
          .timeout(const Duration(seconds: 10));

      // If first attempt fails, try with form data
      if (response.statusCode >= 400) {
        // Create form data body
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
      }

      // If still failing, try with multipart form
      if (response.statusCode >= 400) {
        var request = http.MultipartRequest('POST', Uri.parse(loginUrl));
        request.fields['username'] = username;
        request.fields['password'] = password;

        var streamedResponse =
            await request.send().timeout(const Duration(seconds: 10));
        response = await http.Response.fromStream(streamedResponse);
      }

      // If all above attempts fail, try one last approach with direct query parameters
      if (response.statusCode >= 400) {
        final queryUrl =
            '$loginUrl?username=${Uri.encodeComponent(username)}&password=${Uri.encodeComponent(password)}';

        response = await http.post(
          Uri.parse(queryUrl),
          headers: {
            'Accept': 'application/json',
          },
        ).timeout(const Duration(seconds: 10));
      }

      // Default to authentication failure
      bool isSuccess = false;
      String message = 'Login failed: Invalid credentials';
      Map<String, dynamic> responseData = {};
      bool isJsonResponse = true;

      // Try to parse response as JSON
      try {
        responseData = json.decode(response.body);
      } catch (e) {
        isJsonResponse = false;
        responseData = {'raw_text': response.body};
      }

      // Determine login success based on response
      if (response.statusCode == 200) {
        if (isJsonResponse) {
          // Check for explicit success indicators in JSON response
          if (responseData.containsKey('success') &&
              responseData['success'] == true) {
            isSuccess = true;
            message = responseData['message'] ?? 'Login successful';
          }
          // Check for common auth data patterns
          else if (responseData.containsKey('user') ||
              responseData.containsKey('token') ||
              responseData.containsKey('userData') ||
              responseData.containsKey('auth_token')) {
            isSuccess = true;
            message = 'Login successful';
          }
          // Check for status field
          else if (responseData.containsKey('status') &&
              responseData['status'].toString().toLowerCase() == 'success') {
            isSuccess = true;
            message = 'Login successful';
          }
          // Check for error indicators
          else if (responseData.containsKey('error') ||
              (responseData.containsKey('success') &&
                  responseData['success'] == false)) {
            isSuccess = false;
            message = responseData['message'] ??
                responseData['error'] ??
                'Login failed: Invalid credentials';
          }
          // No clear indicators in response
          else {
            isSuccess = false;
            message =
                'Login failed: No authentication confirmation from server';
          }
        } else {
          // For non-JSON responses, consider login failed
          isSuccess = false;
          message = 'Login failed: Invalid response format from server';
        }
      } else {
        // Non-200 responses always indicate failure
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
      // Clean URL by removing trailing slash if present
      String cleanUrl = apiUrl;
      if (cleanUrl.endsWith('/')) {
        cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
      }

      // Define the login URL - adjust this to match your PHP API endpoint
      final loginUrl = '$cleanUrl/api/login';

      // Try multiple approaches to handle the PHP parameter issue
      List<Future<http.Response>> loginAttempts = [];

      // 1. Standard form data approach
      loginAttempts.add(
        http
            .post(
              Uri.parse(loginUrl),
              headers: {'Content-Type': 'application/x-www-form-urlencoded'},
              body: 'username=$username&password=$password',
            )
            .timeout(const Duration(seconds: 10)),
      );

      // 2. URL query parameters approach
      loginAttempts.add(
        http.post(
          Uri.parse('$loginUrl?username=$username&password=$password'),
          headers: {'Accept': 'application/json'},
        ).timeout(const Duration(seconds: 10)),
      );

      // 3. Malformed parameter name approach (handling &amp;password issue)
      loginAttempts.add(
        http
            .post(
              Uri.parse(loginUrl),
              headers: {'Content-Type': 'application/x-www-form-urlencoded'},
              body: 'username=$username&amp;password=$password',
            )
            .timeout(const Duration(seconds: 10)),
      );

      // 4. Direct GET request with parameters
      loginAttempts.add(
        http.get(
          Uri.parse('$loginUrl?username=$username&password=$password'),
          headers: {'Accept': 'application/json'},
        ).timeout(const Duration(seconds: 10)),
      );

      // Try each approach until one succeeds
      http.Response? successfulResponse;
      String attemptDescription = '';

      for (int i = 0; i < loginAttempts.length; i++) {
        try {
          final response = await loginAttempts[i];

          // If we got a 200 response, consider it successful
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
          // Silently continue to next attempt if this one fails
          // We're trying multiple login approaches, so individual failures are expected
        }
      }

      // If no attempt was successful, return error
      if (successfulResponse == null) {
        return {
          'success': false,
          'message': 'All login attempts failed',
          'url_used': loginUrl,
        };
      }

      // Process the successful response

      // Try to parse response as JSON
      Map<String, dynamic> responseData = {};
      bool isJsonResponse = true;
      try {
        responseData = json.decode(successfulResponse.body);
      } catch (e) {
        isJsonResponse = false;
        responseData = {'raw_text': successfulResponse.body};
      }

      // Check for success indicators in the response
      bool isSuccess = false;
      String message = 'Login failed: Invalid credentials';

      if (isJsonResponse) {
        // Check for status field (common in PHP APIs)
        if (responseData.containsKey('status')) {
          if (responseData['status'] == true ||
              responseData['status'].toString().toLowerCase() == 'true' ||
              responseData['status'].toString().toLowerCase() == 'success') {
            isSuccess = true;
            message = responseData['message'] ?? 'Login successful';
          }
        }

        // Check for user_data field (based on your PHP API)
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
        'url_used': loginUrl,
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
    Map<String, dynamic> results = {};

    try {
      // Clean URL by removing trailing slash if present
      String cleanUrl = apiUrl;
      if (cleanUrl.endsWith('/')) {
        cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
      }

      // Test base URL connection
      try {
        final baseResponse = await http
            .get(Uri.parse(cleanUrl))
            .timeout(const Duration(seconds: 5));
        results['base_url'] = {
          'status': baseResponse.statusCode,
          'success': baseResponse.statusCode < 400,
          'body': baseResponse.body.length > 1000
              ? '${baseResponse.body.substring(0, 1000)}...'
              : baseResponse.body,
        };
      } catch (e) {
        results['base_url'] = {
          'status': 'error',
          'message': e.toString(),
          'success': false,
        };
      }

      // Test login endpoint with HEAD request
      try {
        final loginUrl = '$cleanUrl/api/login';
        final loginHeadResponse = await http
            .head(Uri.parse(loginUrl))
            .timeout(const Duration(seconds: 5));
        results['login_head'] = {
          'status': loginHeadResponse.statusCode,
          'success': loginHeadResponse.statusCode < 400,
        };
      } catch (e) {
        results['login_head'] = {
          'status': 'error',
          'message': e.toString(),
          'success': false,
        };
      }

      // Test login endpoint with empty body
      try {
        final loginUrl = '$cleanUrl/api/login';
        final loginEmptyResponse = await http
            .post(
              Uri.parse(loginUrl),
              headers: {'Content-Type': 'application/json'},
              body: '{}',
            )
            .timeout(const Duration(seconds: 5));
        results['login_empty'] = {
          'status': loginEmptyResponse.statusCode,
          'body': loginEmptyResponse.body.length > 1000
              ? '${loginEmptyResponse.body.substring(0, 1000)}...'
              : loginEmptyResponse.body,
          'success': true, // Just checking if we get a response
        };
      } catch (e) {
        results['login_empty'] = {
          'status': 'error',
          'message': e.toString(),
          'success': false,
        };
      }

      // Test login endpoint with sample credentials
      try {
        final loginUrl = '$cleanUrl/api/login';
        final loginSampleResponse = await http
            .post(
              Uri.parse(loginUrl),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'username': 'test_user',
                'password': 'test_password',
              }),
            )
            .timeout(const Duration(seconds: 5));
        results['login_sample'] = {
          'status': loginSampleResponse.statusCode,
          'body': loginSampleResponse.body.length > 1000
              ? '${loginSampleResponse.body.substring(0, 1000)}...'
              : loginSampleResponse.body,
          'success': true, // Just checking if we get a response
        };
      } catch (e) {
        results['login_sample'] = {
          'status': 'error',
          'message': e.toString(),
          'success': false,
        };
      }

      // Overall diagnosis
      if (results['base_url']['success'] && results['login_head']['success']) {
        results['diagnosis'] = {
          'success': true,
          'message':
              'API connection looks good. The login endpoint is accessible.',
        };
      } else if (!results['base_url']['success']) {
        results['diagnosis'] = {
          'success': false,
          'message':
              'Cannot connect to API server. Check server address and network connection.',
        };
      } else if (!results['login_head']['success']) {
        results['diagnosis'] = {
          'success': false,
          'message':
              'Cannot find login endpoint. API URL may be incorrect or server misconfigured.',
        };
      } else {
        results['diagnosis'] = {
          'success': false,
          'message': 'Unknown connection issue. Check server logs.',
        };
      }

      return results;
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
