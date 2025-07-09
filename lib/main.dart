import 'dart:convert';
import 'package:easytime_online/client_codes_fetch_api.dart';
import 'package:easytime_online/dashboard_screen.dart';
import 'package:easytime_online/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientations
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EasyTime Online',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E3C72),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          elevation: 0,
          backgroundColor: Colors.white,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: Color(0xFF1E3C72),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
          iconTheme: IconThemeData(color: Color(0xFF1E3C72)),
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Color(0xFF333333)),
          bodyMedium: TextStyle(color: Color(0xFF333333)),
          titleLarge: TextStyle(
            color: Color(0xFF1E3C72),
            fontWeight: FontWeight.bold,
          ),
          titleMedium: TextStyle(
            color: Color(0xFF1E3C72),
            fontWeight: FontWeight.w600,
          ),
          titleSmall: TextStyle(
            color: Color(0xFF1E3C72),
            fontWeight: FontWeight.w500,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1E3C72),
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFFE0E0E0)),
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.white,
          selectedItemColor: Color(0xFF1E3C72),
          unselectedItemColor: Color(0xFFAAAAAA),
          selectedLabelStyle: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
          unselectedLabelStyle: TextStyle(fontSize: 12),
          elevation: 0,
        ),
        dividerTheme: DividerThemeData(
          color: Colors.grey.shade100,
          thickness: 1,
          space: 1,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF1E3C72)),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
        // Performance optimizations
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
        // Scrolling physics for better performance
        scrollbarTheme: ScrollbarThemeData(
          thumbColor: WidgetStateProperty.all(Colors.grey.shade300),
          thickness: WidgetStateProperty.all(4),
          radius: const Radius.circular(8),
        ),
      ),
      home: const SplashScreen(),
      builder: (context, child) {
        // Global scrolling behavior
        return ScrollConfiguration(
          behavior: const ScrollBehavior().copyWith(
            physics: const ClampingScrollPhysics(),
            overscroll: false,
          ),
          child: child!,
        );
      },
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.title});
  final String title;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _clientCodeController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool isClientCodeValid = false;
  bool showLoginFields = false;
  String buttonText = 'CHECK';
  String cleartext = 'CLEAR CACHE';
  String? clientApiUrl;
  bool rememberMe = false;
  bool _showPassword = false; // Add this line to track password visibility

  @override
  void initState() {
    super.initState();
    _loadSavedClientCode();
  }

  void _loadSavedClientCode() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? savedCode = prefs.getString('client_code');
    String? savedUserCode = prefs.getString('user_code');
    String? savedPassword = prefs.getString('user_password');
    String? savedBaseApiUrl = prefs.getString('base_api_url');
    bool? savedRemember = prefs.getBool('remember_me') ?? false;

    if (savedCode != null) {
      setState(() {
        _clientCodeController.text = savedCode;
        isClientCodeValid = true;
        showLoginFields = true;
        buttonText = 'LOGIN';
      });

      // Try to verify client code with ApiService
      try {
        final result = await ApiService.verifyClientCode(savedCode);

        if (result['success']) {
          setState(() {
            clientApiUrl = result['api_url'];
          });

          // Test if the login URL is accessible
          bool isLoginUrlAccessible = await _testLoginUrlAvailability();

          if (!isLoginUrlAccessible && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    'Warning: Login server might not be accessible with saved client code.'),
                duration: Duration(seconds: 5),
              ),
            );
          }
        } else if (savedBaseApiUrl != null) {
          // Use previously saved base URL if available
          setState(() {
            clientApiUrl = savedBaseApiUrl;
          });

          // Test if the saved URL is accessible
          bool isSavedUrlAccessible = await _testLoginUrlAvailability();

          if (!isSavedUrlAccessible && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    'Warning: Saved login server might not be accessible.'),
                duration: Duration(seconds: 5),
              ),
            );
          }
        }
      } catch (e) {
        if (savedBaseApiUrl != null) {
          setState(() {
            clientApiUrl = savedBaseApiUrl;
          });
        } else {
          setState(() {
            clientApiUrl = ApiService.defaultBaseUrl;
          });
        }
      }

      if (savedUserCode != null && savedPassword != null) {
        setState(() {
          _usernameController.text = savedUserCode;
          _passwordController.text = savedPassword;
          rememberMe = savedRemember;
        });
      }
    }
  }

  void _clearClientCode() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('client_code');
    await prefs.remove('user_code');
    await prefs.remove('user_password');
    await prefs.remove('remember_me');
    await prefs.remove('base_api_url');

    setState(() {
      _clientCodeController.clear();
      _usernameController.clear();
      _passwordController.clear();
      isClientCodeValid = false;
      showLoginFields = false;
      buttonText = 'CHECK';
      clientApiUrl = null;
    });
  }

  void checkClientCode() async {
    String enteredCode = _clientCodeController.text.trim();
    final BuildContext currentContext = context;

    if (enteredCode.isEmpty) {
      _showCustomToast('Please enter a client code', isSuccess: false);
      return;
    }

    // Show loading indicator
    showDialog(
      context: currentContext,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Center(
          child: CircularProgressIndicator(),
        );
      },
    );

    try {
      final result = await ApiService.verifyClientCode(enteredCode);

      if (!mounted) return;
      Navigator.pop(currentContext); // Close loading dialog

      if (result['success']) {
        // Save both the client code and API URL
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('client_code', enteredCode);

        final apiUrl = result['api_url'];
        await ApiService.setApiUrl(apiUrl);

        setState(() {
          isClientCodeValid = true;
          showLoginFields = true;
          buttonText = 'LOGIN';
          clientApiUrl = apiUrl;
        });

        // Test if the login URL is actually accessible
        bool isLoginUrlAccessible = await _testLoginUrlAvailability();

        if (!isLoginUrlAccessible && mounted) {
          _showCustomToast(
            'Warning: Login server might not be accessible. Check your connection.',
            isSuccess: false,
          );
        }
      } else {
        if (!mounted) return;
        _showCustomToast(
          result['message'] ?? 'Invalid client code',
          isSuccess: false,
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(currentContext); // Close loading dialog
      _showCustomToast('Error: ${e.toString()}', isSuccess: false);
    }
  }

  void login() async {
    // Dismiss keyboard
    FocusScope.of(context).unfocus();

    String username = _usernameController.text.trim();
    String password = _passwordController.text;

    // Validation checks
    if (username.isEmpty || password.isEmpty) {
      _showCustomToast('Please fill all fields', isSuccess: false);
      return;
    }

    // Directly use normal login without showing debug dialog
    _normalLogin();
  }

  void _normalLogin() async {
    // Dismiss keyboard
    FocusScope.of(context).unfocus();

    String username = _usernameController.text.trim();
    String password = _passwordController.text;

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Center(
          child: CircularProgressIndicator(),
        );
      },
    );

    try {
      // Make sure we have the API URL
      if (clientApiUrl == null || clientApiUrl!.isEmpty) {
        clientApiUrl = await ApiService.getClientApiUrl();
      }

      // Call API service with our new PHP API login method
      final result = await ApiService.loginWithPhpApi(
        clientApiUrl!,
        username,
        password,
      );

      if (!mounted) return;
      Navigator.pop(context); // Close loading

      // Process result
      final bool loginSuccess = result['success'] == true;
      final String message = result['message'] ??
          (loginSuccess ? 'Login successful' : 'Login failed');

      // Show better styled toast message
      _showCustomToast(message, isSuccess: loginSuccess);

      // If login successful, navigate to dashboard
      if (loginSuccess) {
        // Save credentials if remember me is checked
        if (rememberMe) {
          final SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_code', username);
          await prefs.setString('user_password', password);
          await prefs.setBool('remember_me', rememberMe);
          if (clientApiUrl != null) {
            await prefs.setString('base_api_url', clientApiUrl!);
          }
        }

        // Extract user data from response
        Map<String, dynamic> userData = {};
        if (result['response_data'].containsKey('user_data')) {
          userData = result['response_data']['user_data'];
        }

        // Navigate to dashboard
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => DashboardScreen(
                  userName: userData['emp_name'] ?? username,
                  userData:
                      userData, // Pass the full user data including emp_key
                ),
              ),
            );
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      // Show error toast
      _showCustomToast('Login error: ${e.toString()}', isSuccess: false);
    }
  }

  // Simple toast message
  void _showCustomToast(String message, {required bool isSuccess}) {
    // Dismiss keyboard first
    FocusScope.of(context).unfocus();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess ? Colors.green[600] : Colors.red[600],
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // Function to display raw request/response information for debugging
  void _showRawApiRequestInfo() {
    String username = _usernameController.text.trim();
    String password = _passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      _showCustomToast('Please enter username and password', isSuccess: false);
      return;
    }

    if (clientApiUrl == null || clientApiUrl!.isEmpty) {
      _showCustomToast('API URL not set. Please verify client code',
          isSuccess: false);
      return;
    }

    // Clean URL
    String cleanUrl = clientApiUrl!;
    if (cleanUrl.endsWith('/')) {
      cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
    }

    // Create login URL
    final loginUrl = '$cleanUrl/api/login';

    // Create raw request body
    final Map<String, dynamic> requestBody = {
      'username': username,
      'password': password,
    };

    // JSON encode request body
    final String jsonRequestBody = jsonEncode(requestBody);

    // Verify proper JSON encoding

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('API Request Information'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Raw Request Information:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('URL: $loginUrl'),
              const SizedBox(height: 4),
              const Text('Headers:'),
              const Text('  Content-Type: application/json'),
              const Text('  Accept: application/json'),
              const SizedBox(height: 4),
              const Text('JSON Body:'),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  jsonRequestBody,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
              const SizedBox(height: 4),
              Text('Body Keys: ${requestBody.keys.toList()}'),
              Text('Contains username: ${jsonRequestBody.contains(username)}'),
              Text('Contains password: ${jsonRequestBody.contains(password)}'),
              const SizedBox(height: 8),
              const Text('Send this request to the API?'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _sendRawApiRequest(loginUrl, jsonRequestBody);
            },
            child: const Text('Send Request'),
          ),
        ],
      ),
    );
  }

  // Function to send a raw API request
  void _sendRawApiRequest(String url, String jsonRequestBody) {
    // Dismiss keyboard
    FocusScope.of(context).unfocus();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Center(
          child: CircularProgressIndicator(),
        );
      },
    );

    try {
      // Verify if the body is valid JSON
      final decodedBody = json.decode(jsonRequestBody);
    } catch (e) {
      // Error parsing body
    }

    // Use direct http package to make request
    http
        .post(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonRequestBody,
    )
        .then((response) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      // Parse response
      String responseMessage = '';
      bool isJsonResponse = true;
      Map<String, dynamic> responseData = {};
      bool isSuccess = false;

      try {
        responseData = json.decode(response.body);
        isSuccess = responseData['success'] == true;
        responseMessage = responseData['message'] ?? 'No message provided';
      } catch (e) {
        isJsonResponse = false;
        responseMessage = 'Could not parse server response';
      }

      // Show toast message
      _showCustomToast(responseMessage, isSuccess: isSuccess);

      // If login successful, navigate to dashboard after a short delay
      if (isSuccess) {
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            // Navigate to dashboard
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => DashboardScreen(
                  userName: _usernameController.text.trim(),
                  userData:
                      isJsonResponse ? {'response_data': responseData} : null,
                ),
              ),
            );
          }
        });
      }
    }).catchError((error) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      // Show error toast
      _showCustomToast('Error sending request: $error', isSuccess: false);
    });
  }

  // Add this method to test if the login URL is accessible
  Future<bool> _testLoginUrlAvailability() async {
    try {
      // Get current API URL
      final apiUrl = await ApiService.getClientApiUrl();
      final loginUrl = '$apiUrl/api/login';

      // Send a HEAD request to check if the login endpoint is available
      final response = await http
          .head(Uri.parse(loginUrl))
          .timeout(const Duration(seconds: 5));

      // Consider anything below 400 as success
      return response.statusCode < 400;
    } catch (e) {
      return false;
    }
  }

  // Add this to verify the client code really gives us a working API URL
  Future<void> _verifyClientApiUrlWorks() async {
    if (!isClientCodeValid || clientApiUrl == null) return;

    final bool isLoginUrlAccessible = await _testLoginUrlAvailability();

    if (!isLoginUrlAccessible && mounted) {
      _showCustomToast('Warning: Login server may not be accessible',
          isSuccess: false);
    }
  }

  // Double-check login credentials before navigating to dashboard
  Future<bool> _validateCredentials(String username, String password) async {
    try {
      // Make a direct API call to validate credentials
      final apiUrl = await ApiService.getClientApiUrl();
      final loginUrl = '$apiUrl/api/login';

      final response = await http.post(
        Uri.parse(loginUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      );

      // Check the response
      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          // Look for indicators of successful authentication
          if (data.containsKey('success') && data['success'] == true) {
            return true;
          }
          if (data.containsKey('user') ||
              data.containsKey('token') ||
              data.containsKey('userData')) {
            return true;
          }
          // If none of the success indicators are present, assume failure
          return false;
        } catch (e) {
          return false;
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // Function to ensure proper login request with credentials
  Future<void> _ensureProperLoginRequest() async {
    // Get credentials from text fields
    String username = _usernameController.text.trim();
    String password = _passwordController.text;

    // Validate credentials
    if (username.isEmpty || password.isEmpty) {
      _showCustomToast('Please enter both username and password',
          isSuccess: false);
      return;
    }

    // Show loading indicator
    setState(() {
      buttonText = 'CHECKING...';
    });

    try {
      // Make sure we have the API URL
      if (clientApiUrl == null || clientApiUrl!.isEmpty) {
        clientApiUrl = await ApiService.getClientApiUrl();
      }

      // Clean URL
      String cleanUrl = clientApiUrl!;
      if (cleanUrl.endsWith('/')) {
        cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
      }

      // Show dialog with request details
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('PHP API Login Request'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                    'This will attempt multiple login approaches to handle the PHP API parameter issue.',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Text('API URL: $cleanUrl/api/login'),
                const SizedBox(height: 8),
                Text('Username: $username'),
                Text('Password: ${password.replaceAll(RegExp('.'), '*')}'),
                const SizedBox(height: 16),
                const Text('Approaches that will be tried:'),
                const SizedBox(height: 8),
                const Text('1. Standard form data'),
                const Text('2. URL query parameters'),
                const Text(
                    '3. Malformed parameter name (handling &amp;password)'),
                const Text('4. Direct GET request'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                setState(() {
                  buttonText = 'LOGIN';
                });
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _executePhpApiLogin(cleanUrl, username, password);
              },
              child: const Text('Proceed'),
            ),
          ],
        ),
      );
    } catch (e) {
      setState(() {
        buttonText = 'LOGIN';
      });
      _showCustomToast('Error: ${e.toString()}', isSuccess: false);
    }
  }

  // Execute PHP API login with detailed response
  void _executePhpApiLogin(
      String apiUrl, String username, String password) async {
    // Dismiss keyboard
    FocusScope.of(context).unfocus();

    // Show loading indicator
    setState(() {
      buttonText = 'SENDING...';
    });

    try {
      // Call our new PHP API login method
      final result =
          await ApiService.loginWithPhpApi(apiUrl, username, password);

      setState(() {
        buttonText = 'LOGIN';
      });

      // Determine if login was successful
      bool isSuccess = result['success'] == true;
      String message = result['message'] ?? 'Unknown response';

      // Show toast message
      _showCustomToast(message, isSuccess: isSuccess);

      // If login successful, navigate to dashboard after a short delay
      if (isSuccess) {
        // Extract user data from response
        Map<String, dynamic> userData = {};
        if (result['response_data'].containsKey('user_data')) {
          userData = result['response_data']['user_data'];
        }

        // Navigate to dashboard
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => DashboardScreen(
                  userName: userData['emp_name'] ?? username,
                  userData: {'user_data': userData},
                ),
              ),
            );
          }
        });
      }
    } catch (e) {
      setState(() {
        buttonText = 'LOGIN';
      });
      _showCustomToast('Error: ${e.toString()}', isSuccess: false);
    }
  }

  void handleButtonPress() {
    // Dismiss keyboard
    FocusScope.of(context).unfocus();

    if (!isClientCodeValid) {
      checkClientCode();
    } else {
      login();
    }
  }

  // Add debug button to UI
  Widget _buildDebugButton() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TextButton(
          onPressed: () {
            if (isClientCodeValid) {
              _showRawApiRequestInfo();
            } else {
              _showCustomToast('Please verify client code first',
                  isSuccess: false);
            }
          },
          child: const Text('DEBUG API'),
          style: TextButton.styleFrom(
            foregroundColor: Colors.red,
          ),
        ),
        TextButton(
          onPressed: () {
            if (isClientCodeValid) {
              _runApiCompatibilityTest();
            } else {
              _showCustomToast('Please verify client code first',
                  isSuccess: false);
            }
          },
          child: const Text('TEST ALL API FORMATS'),
          style: TextButton.styleFrom(
            foregroundColor: Colors.orange,
          ),
        ),
      ],
    );
  }

  // Method to test all possible API request formats to find which one works
  Future<void> _runApiCompatibilityTest() async {
    if (clientApiUrl == null || clientApiUrl!.isEmpty) {
      _showCustomToast('Error: API URL not set', isSuccess: false);
      return;
    }

    String username = _usernameController.text.trim();
    String password = _passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      _showCustomToast('Please enter username and password', isSuccess: false);
      return;
    }

    // Dismiss keyboard
    FocusScope.of(context).unfocus();

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Center(
          child: CircularProgressIndicator(),
        );
      },
    );

    try {
      // Clean URL
      String cleanUrl = clientApiUrl!;
      if (cleanUrl.endsWith('/')) {
        cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
      }

      // Create login URL
      final loginUrl = '$cleanUrl/api/login';
      final results = <String, Map<String, dynamic>>{};

      // 1. Test standard JSON
      try {
        final jsonBody = jsonEncode({
          'username': username,
          'password': password,
        });

        final response = await http
            .post(
              Uri.parse(loginUrl),
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
              },
              body: jsonBody,
            )
            .timeout(const Duration(seconds: 5));

        results['JSON'] = {
          'status': response.statusCode,
          'body': response.body,
          'success': response.statusCode < 400,
        };
      } catch (e) {
        results['JSON'] = {
          'status': 'error',
          'body': e.toString(),
          'success': false,
        };
      }

      // 2. Test form URL encoded
      try {
        final formBody =
            'username=${Uri.encodeComponent(username)}&password=${Uri.encodeComponent(password)}';

        final response = await http
            .post(
              Uri.parse(loginUrl),
              headers: {
                'Content-Type': 'application/x-www-form-urlencoded',
                'Accept': 'application/json',
              },
              body: formBody,
            )
            .timeout(const Duration(seconds: 5));

        results['Form-URL'] = {
          'status': response.statusCode,
          'body': response.body,
          'success': response.statusCode < 400,
        };
      } catch (e) {
        results['Form-URL'] = {
          'status': 'error',
          'body': e.toString(),
          'success': false,
        };
      }

      // 3. Test multipart form
      try {
        final request = http.MultipartRequest('POST', Uri.parse(loginUrl));
        request.fields['username'] = username;
        request.fields['password'] = password;

        final streamedResponse =
            await request.send().timeout(const Duration(seconds: 5));
        final response = await http.Response.fromStream(streamedResponse);

        results['Multipart'] = {
          'status': response.statusCode,
          'body': response.body,
          'success': response.statusCode < 400,
        };
      } catch (e) {
        results['Multipart'] = {
          'status': 'error',
          'body': e.toString(),
          'success': false,
        };
      }

      // 4. Test query parameters
      try {
        final queryUrl =
            '$loginUrl?username=${Uri.encodeComponent(username)}&password=${Uri.encodeComponent(password)}';

        final response = await http.post(
          Uri.parse(queryUrl),
          headers: {'Accept': 'application/json'},
        ).timeout(const Duration(seconds: 5));

        results['Query-Param'] = {
          'status': response.statusCode,
          'body': response.body,
          'success': response.statusCode < 400,
        };
      } catch (e) {
        results['Query-Param'] = {
          'status': 'error',
          'body': e.toString(),
          'success': false,
        };
      }

      // 5. Test raw form parameters (no Content-Type)
      try {
        final formBody =
            'username=${Uri.encodeComponent(username)}&password=${Uri.encodeComponent(password)}';

        final response = await http
            .post(
              Uri.parse(loginUrl),
              body: formBody,
            )
            .timeout(const Duration(seconds: 5));

        results['Raw-Form'] = {
          'status': response.statusCode,
          'body': response.body,
          'success': response.statusCode < 400,
        };
      } catch (e) {
        results['Raw-Form'] = {
          'status': 'error',
          'body': e.toString(),
          'success': false,
        };
      }

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      // Find the best working method
      final successMethods = results.entries
          .where((entry) => entry.value['success'] == true)
          .map((entry) => entry.key)
          .toList();

      final recommended =
          successMethods.isNotEmpty ? successMethods.first : 'None';

      // Show simplified results
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('API Test Results'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Working methods: ${successMethods.isEmpty ? "None" : successMethods.join(", ")}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: successMethods.isEmpty ? Colors.red : Colors.green,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Recommended method: $recommended',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      _showCustomToast('Error: ${e.toString()}', isSuccess: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: const Color(0xFF1E2A38),
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: Center(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: Container(
              width: 400,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 10),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Secure Login",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 30),
                  TextField(
                    controller: _clientCodeController,
                    enabled: !isClientCodeValid,
                    decoration: const InputDecoration(
                      labelText: 'Client Code',
                      prefixIcon: Icon(Icons.business),
                    ),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 20),
                  if (showLoginFields) ...[
                    TextField(
                      controller: _usernameController,
                      enabled: true,
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        prefixIcon: Icon(Icons.person),
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _passwordController,
                      obscureText:
                          !_showPassword, // Use the visibility flag here
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _showPassword
                                ? Icons.visibility
                                : Icons.visibility_off,
                            color: Colors.grey,
                          ),
                          onPressed: () {
                            setState(() {
                              _showPassword = !_showPassword;
                            });
                          },
                        ),
                      ),
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) {
                        handleButtonPress();
                      },
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Remember Me',
                            style: TextStyle(fontSize: 16)),
                        Switch(
                          value: rememberMe,
                          onChanged: (value) {
                            setState(() {
                              rememberMe = value;
                            });
                          },
                          activeColor: const Color(0xFF2C3E50),
                        ),
                      ],
                    ),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: handleButtonPress,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2C3E50),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(buttonText),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _clearClientCode,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade600,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(cleartext),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _clientCodeController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}

// API Testing Screen to help debug login issues
class ApiTestScreen extends StatefulWidget {
  const ApiTestScreen({super.key});

  @override
  State<ApiTestScreen> createState() => _ApiTestScreenState();
}

class _ApiTestScreenState extends State<ApiTestScreen> {
  final TextEditingController _usernameController =
      TextEditingController(text: 'admin');
  final TextEditingController _passwordController =
      TextEditingController(text: 'admin123');
  final TextEditingController _apiUrlController = TextEditingController();

  String _responseText = '';
  bool _isLoading = false;
  bool _isSuccess = false;
  int _responseCode = 0;
  bool _showPassword = false;

  @override
  void initState() {
    super.initState();
    _loadApiUrl();
  }

  void _loadApiUrl() async {
    final apiUrl = await ApiService.getClientApiUrl();
    setState(() {
      _apiUrlController.text = apiUrl;
    });
  }

  Future<void> _testLogin() async {
    setState(() {
      _isLoading = true;
      _responseText = 'Sending request...';
    });

    try {
      final username = _usernameController.text.trim();
      final password = _passwordController.text;
      final apiUrl = _apiUrlController.text.trim();

      if (apiUrl.isEmpty) {
        setState(() {
          _isLoading = false;
          _responseText = 'Error: API URL cannot be empty';
          _isSuccess = false;
        });
        return;
      }

      // Clean URL by removing trailing slash if present
      String cleanUrl = apiUrl;
      if (cleanUrl.endsWith('/')) {
        cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
      }

      // Create the login URL
      final loginUrl = '$cleanUrl/api/login';

      // Create request body
      final Map<String, dynamic> requestBody = {
        'username': username,
        'password': password,
      };

      // Send direct HTTP request
      final response = await http
          .post(
            Uri.parse(loginUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 10));

      // Format response for display
      String formattedResponse = '';
      try {
        // Try to parse and prettify JSON
        final jsonData = json.decode(response.body);
        formattedResponse =
            const JsonEncoder.withIndent('  ').convert(jsonData);
      } catch (e) {
        // If not valid JSON, show as plain text
        formattedResponse = response.body;
      }

      setState(() {
        _isLoading = false;
        _responseText = formattedResponse;
        _responseCode = response.statusCode;
        _isSuccess = response.statusCode == 200;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _responseText = 'Error: ${e.toString()}';
        _isSuccess = false;
      });
    }
  }

  Future<void> _testApiConnection() async {
    setState(() {
      _isLoading = true;
      _responseText = 'Testing API connection...';
    });

    try {
      final apiUrl = _apiUrlController.text.trim();

      if (apiUrl.isEmpty) {
        setState(() {
          _isLoading = false;
          _responseText = 'Error: API URL cannot be empty';
          _isSuccess = false;
        });
        return;
      }

      final testResults = await ApiService.testApiConnection(apiUrl);

      // Format results as JSON for display
      final formattedResults =
          const JsonEncoder.withIndent('  ').convert(testResults);

      setState(() {
        _isLoading = false;
        _responseText = formattedResults;
        _isSuccess = testResults['diagnosis']['success'] == true;
        _responseCode = 0;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _responseText = 'Error: ${e.toString()}';
        _isSuccess = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('API Testing'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'API URL:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              TextField(
                controller: _apiUrlController,
                decoration: const InputDecoration(
                  hintText: 'http://example.com',
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              const Text(
                'Login Credentials:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              TextField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'Username',
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'Password',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _showPassword ? Icons.visibility : Icons.visibility_off,
                      color: Colors.grey,
                    ),
                    onPressed: () {
                      setState(() {
                        _showPassword = !_showPassword;
                      });
                    },
                  ),
                ),
                obscureText: !_showPassword,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _testLogin(),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _testLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Test Login API'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _testApiConnection,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Test API Connection'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Response:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  if (_responseCode > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _isSuccess ? Colors.green : Colors.red,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Status: $_responseCode',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : SelectableText(
                        _responseText,
                        style: const TextStyle(
                            fontFamily: 'monospace', fontSize: 14),
                      ),
              ),
              const SizedBox(height: 24),
              const Text(
                'API Tips:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              const Text(
                  '• Login API should return success: true for valid credentials'),
              const Text('• Response should have status code 200 for success'),
              const Text('• Invalid credentials should return success: false'),
              const SizedBox(height: 8),
              const Text(
                'Example Success Response:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '{\n  "success": true,\n  "message": "Login successful",\n  "user": {\n    "id": 1,\n    "name": "Admin"\n  }\n}',
                  style: TextStyle(fontFamily: 'monospace', fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _apiUrlController.dispose();
    super.dispose();
  }
}
