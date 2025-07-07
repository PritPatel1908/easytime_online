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
      print('⚠️ Verifying client code: $clientCode');
      final verifyUrl = '$defaultBaseUrl/api/verify-client-code';
      print('⚠️ Using verify URL: $verifyUrl');

      final response = await http.post(
        Uri.parse(verifyUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'client_code': clientCode}),
      );

      print('⚠️ Verify response status: ${response.statusCode}');
      print('⚠️ Verify response body: ${response.body}');

      if (response.statusCode == 200) {
        // Try to parse response body
        Map<String, dynamic> data;
        try {
          data = json.decode(response.body);
          print('⚠️ Parsed verify response: $data');
        } catch (e) {
          print('⚠️ Error parsing verify response: $e');
          return {'success': false, 'message': 'Error parsing server response'};
        }

        // Extract the API URL from the response
        String baseApiUrl;
        if (data.containsKey('api_url')) {
          baseApiUrl = data['api_url'];
          print('⚠️ Found api_url in response: $baseApiUrl');
        } else if (data.containsKey('url')) {
          baseApiUrl = data['url'];
          print('⚠️ Found url in response: $baseApiUrl');
        } else {
          // If neither field exists, use default
          baseApiUrl = defaultBaseUrl;
          print('⚠️ No URL found in response, using default: $baseApiUrl');
        }

        // Remove trailing slash if present
        if (baseApiUrl.endsWith('/')) {
          baseApiUrl = baseApiUrl.substring(0, baseApiUrl.length - 1);
        }

        // Save to shared preferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('base_api_url', baseApiUrl);
        print('⚠️ Saved base_api_url: $baseApiUrl');

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
          print('⚠️ Error parsing error response: $e');
        }

        return {
          'success': false,
          'message': errorMessage,
          'status_code': response.statusCode
        };
      }
    } catch (e) {
      print('⚠️ Client code verification error: $e');
      return {'success': false, 'message': 'Connection error: ${e.toString()}'};
    }
  }

  // IMPORTANT: This method is kept for compatibility but we recommend using directLogin instead
  static Future<Map<String, dynamic>> login(
      String username, String password) async {
    try {
      final apiUrl = await getClientApiUrl();
      print('⚠️ LOGIN using API URL: $apiUrl');

      // Forward to directLogin for consistent behavior
      return directLogin(apiUrl, username, password);
    } catch (e) {
      print('⚠️ LOGIN error: $e');
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
      print('⚠️ DIRECT LOGIN with URL: $loginUrl');
      print('⚠️ Username: $username, Password length: ${password.length}');

      // IMPORTANT: Create proper request body with username and password
      final requestBody = jsonEncode({
        'username': username,
        'password': password,
      });

      print('⚠️ Request body (raw): $requestBody');
      print('⚠️ Request body keys: ${json.decode(requestBody).keys.toList()}');

      // Send login request to API with proper headers
      final response = await http
          .post(
            Uri.parse(loginUrl),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: requestBody,
          )
          .timeout(const Duration(seconds: 10));

      print('⚠️ LOGIN response code: ${response.statusCode}');
      print('⚠️ LOGIN response body: ${response.body}');

      // For debugging: Check if request was properly formatted
      print('⚠️ Request was sent with:');
      print('⚠️ - URL: $loginUrl');
      print('⚠️ - Content-Type: application/json');
      print('⚠️ - Body: $requestBody');

      // Default to authentication failure
      bool isSuccess = false;
      String message = 'Login failed: Invalid credentials';
      Map<String, dynamic> responseData = {};
      bool isJsonResponse = true;

      // Try to parse response as JSON
      try {
        responseData = json.decode(response.body);
        print('⚠️ Parsed response data: $responseData');
      } catch (e) {
        print('⚠️ Not a JSON response: $e');
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

      print('⚠️ Login result: success=$isSuccess, message=$message');

      // Return detailed response for debugging
      return {
        'success': isSuccess,
        'message': message,
        'response_code': response.statusCode,
        'response_body': response.body,
        'response_data': responseData,
        'url_used': loginUrl,
        'request_sent': json.decode(requestBody),
      };
    } catch (e) {
      print('⚠️ DIRECT LOGIN error: $e');
      return {
        'success': false,
        'message': 'Error connecting to server: ${e.toString()}',
        'url_used': '$apiUrl/api/login'
      };
    }
  }

  // Helper to get saved client code
  static Future<String?> _getSavedClientCode() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('client_code');
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
    print('⚠️ API URL directly set to: $cleanUrl');
  }

  // Set up for local development server
  static Future<void> setupLocalServer(String port) async {
    final localUrl = 'http://127.0.0.1:$port';
    print('⚠️ Setting up local development server at: $localUrl');

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

  // Special validation for local development server
  static bool _validateLocalServerLogin(String username, String password) {
    // Add your required credentials here - only these will work
    const validCredentials = {
      'admin': 'admin123',
      'user': 'user123',
      'test': 'test123',
    };

    // Check if provided credentials match any valid credentials
    if (validCredentials.containsKey(username)) {
      return validCredentials[username] == password;
    }

    // If username not found in valid credentials, login fails
    return false;
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
