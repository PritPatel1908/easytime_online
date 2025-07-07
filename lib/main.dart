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

    print('Loading saved preferences:');
    print('- client_code: ${savedCode ?? 'not found'}');
    print('- user_code: ${savedUserCode != null ? 'found' : 'not found'}');
    print('- user_password: ${savedPassword != null ? 'found' : 'not found'}');
    print('- base_api_url: ${savedBaseApiUrl ?? 'not found'}');
    print('- remember_me: $savedRemember');

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
          print('Updated clientApiUrl to: ${result['api_url']}');

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
          print('Using previously saved base_api_url: $savedBaseApiUrl');

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
        print('Error re-verifying client code: $e');
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
      ScaffoldMessenger.of(currentContext).showSnackBar(
        const SnackBar(content: Text('Please enter a client code')),
      );
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

        print('✅ Client code verified. Using API URL: $apiUrl');

        // Show success message
        ScaffoldMessenger.of(currentContext).showSnackBar(
          SnackBar(
            content: Text('Client code verified. Connected to: $apiUrl'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );

        // Test if the login URL is actually accessible
        bool isLoginUrlAccessible = await _testLoginUrlAvailability();

        if (!isLoginUrlAccessible && mounted) {
          ScaffoldMessenger.of(currentContext).showSnackBar(
            const SnackBar(
              content: Text(
                  'Warning: Login server might not be accessible. Check your connection.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 5),
            ),
          );
        }
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(currentContext).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Invalid client code'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(currentContext); // Close loading dialog
      ScaffoldMessenger.of(currentContext).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void login() async {
    String username = _usernameController.text.trim();
    String password = _passwordController.text;

    // Validation checks
    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all fields'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Show debug option dialog
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Login Method Selection'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Choose login method:'),
            SizedBox(height: 8),
            Text('• Normal Login: Uses the ApiService.directLogin method'),
            Text('• Debug Login: Shows raw request details before sending'),
            Text('• Raw HTTP: Uses direct http package call'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _normalLogin();
            },
            child: const Text('Normal Login'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _showRawApiRequestInfo();
            },
            child: const Text('Debug Login'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _ensureProperLoginRequest();
            },
            child: const Text('Raw HTTP'),
          ),
        ],
      ),
    );
  }

  void _normalLogin() async {
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

      // Call API service
      final result = await ApiService.directLogin(
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

      // Show feedback
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: loginSuccess ? Colors.green : Colors.red,
          duration: Duration(seconds: loginSuccess ? 2 : 4),
        ),
      );

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

        // Navigate to dashboard
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => DashboardScreen(userName: username),
              ),
            );
          }
        });
      } else {
        // Show more detailed error dialog
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Login Failed'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Error: $message'),
                  const SizedBox(height: 12),
                  const Text('Technical Details:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('Response Code: ${result['response_code']}'),
                  const SizedBox(height: 8),
                  const Text('Response Data:'),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: SelectableText(
                      '${result['response_data']}',
                      style: const TextStyle(
                          fontFamily: 'monospace', fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text('Request Sent:'),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: SelectableText(
                      '${result['request_sent']}',
                      style: const TextStyle(
                          fontFamily: 'monospace', fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      // Show error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Login error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Function to display raw request/response information for debugging
  void _showRawApiRequestInfo() {
    String username = _usernameController.text.trim();
    String password = _passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter username and password'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (clientApiUrl == null || clientApiUrl!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('API URL not set. Please verify client code'),
          backgroundColor: Colors.red,
        ),
      );
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
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Center(
          child: CircularProgressIndicator(),
        );
      },
    );

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
      String formattedResponse = '';
      bool isJsonResponse = true;
      Map<String, dynamic> responseData = {};

      try {
        responseData = json.decode(response.body);
        formattedResponse =
            const JsonEncoder.withIndent('  ').convert(responseData);
      } catch (e) {
        isJsonResponse = false;
        formattedResponse = response.body;
      }

      // Show response dialog
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('API Response (${response.statusCode})'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Status: ${response.statusCode}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color:
                        response.statusCode < 400 ? Colors.green : Colors.red,
                  ),
                ),
                const SizedBox(height: 8),
                const Text('Headers:'),
                for (var entry in response.headers.entries)
                  Text('  ${entry.key}: ${entry.value}'),
                const SizedBox(height: 8),
                const Text('Response Body:'),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: SelectableText(
                    formattedResponse,
                    style:
                        const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                ),
                if (isJsonResponse) ...[
                  const SizedBox(height: 8),
                  const Text('Response Keys:'),
                  Text(responseData.keys.toList().toString()),
                ],
                const SizedBox(height: 16),
                const Text('Login Successful?',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  isJsonResponse &&
                          responseData.containsKey('success') &&
                          responseData['success'] == true
                      ? '✅ Yes'
                      : '❌ No',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isJsonResponse &&
                            responseData.containsKey('success') &&
                            responseData['success'] == true
                        ? Colors.green
                        : Colors.red,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
            if (isJsonResponse &&
                responseData.containsKey('success') &&
                responseData['success'] == true)
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx); // Close dialog

                  // Navigate to dashboard
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DashboardScreen(
                        userName: _usernameController.text.trim(),
                      ),
                    ),
                  );
                },
                child: const Text('Go to Dashboard'),
              ),
          ],
        ),
      );
    }).catchError((error) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      // Show error dialog
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Request Error'),
          content: Text('Error sending request: $error'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    });
  }

  // Add this method to test if the login URL is accessible
  Future<bool> _testLoginUrlAvailability() async {
    try {
      // Get current API URL
      final apiUrl = await ApiService.getClientApiUrl();
      final loginUrl = '$apiUrl/api/login';

      print('Testing login URL availability: $loginUrl');

      // Send a HEAD request to check if the login endpoint is available
      final response = await http
          .head(Uri.parse(loginUrl))
          .timeout(const Duration(seconds: 5));

      print('Login URL test response: ${response.statusCode}');

      // Consider anything below 400 as success
      return response.statusCode < 400;
    } catch (e) {
      print('Login URL test error: $e');
      return false;
    }
  }

  // Add this to verify the client code really gives us a working API URL
  Future<void> _verifyClientApiUrlWorks() async {
    if (!isClientCodeValid || clientApiUrl == null) return;

    final bool isLoginUrlAccessible = await _testLoginUrlAvailability();

    if (!isLoginUrlAccessible && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Warning: Login server may not be accessible')),
      );
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

      print('Credential validation response: ${response.statusCode}');
      print('Credential validation body: ${response.body}');

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
          print('Error parsing credential validation response: $e');
          return false;
        }
      }
      return false;
    } catch (e) {
      print('Credential validation error: $e');
      return false;
    }
  }

  // Function to ensure proper login request with credentials
  Future<void> _ensureProperLoginRequest() async {
    if (clientApiUrl == null || clientApiUrl!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: API URL not set'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    String username = _usernameController.text.trim();
    String password = _passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter username and password'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

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

      // Create request body
      final Map<String, dynamic> requestBody = {
        'username': username,
        'password': password,
      };

      // Encode the request body
      final String jsonBody = jsonEncode(requestBody);

      print('⚠️ DIRECT API REQUEST:');
      print('⚠️ URL: $loginUrl');
      print('⚠️ Body: $jsonBody');
      print('⚠️ Username: $username');
      print('⚠️ Password length: ${password.length}');

      // Make direct HTTP request
      final response = await http
          .post(
            Uri.parse(loginUrl),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonBody,
          )
          .timeout(const Duration(seconds: 10));

      print('⚠️ DIRECT API RESPONSE:');
      print('⚠️ Status code: ${response.statusCode}');
      print('⚠️ Body: ${response.body}');

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      // Check if response is JSON
      Map<String, dynamic> responseData = {};
      bool isJsonResponse = true;
      String formattedResponse = '';

      try {
        responseData = json.decode(response.body);
        formattedResponse =
            const JsonEncoder.withIndent('  ').convert(responseData);
      } catch (e) {
        isJsonResponse = false;
        formattedResponse = response.body;
      }

      // Determine if login was successful
      bool isSuccess = false;
      if (response.statusCode == 200 && isJsonResponse) {
        if (responseData.containsKey('success')) {
          isSuccess = responseData['success'] == true;
        } else if (responseData.containsKey('user') ||
            responseData.containsKey('token') ||
            responseData.containsKey('userData')) {
          isSuccess = true;
        }
      }

      // Show response dialog with option to go to dashboard if successful
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(isSuccess ? 'Login Successful' : 'Login Failed'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Status: ${response.statusCode}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isSuccess ? Colors.green : Colors.red,
                  ),
                ),
                const SizedBox(height: 8),
                const Text('Request Details:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Text('URL: $loginUrl'),
                Text('Username: $username'),
                const SizedBox(height: 8),
                const Text('Response:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    formattedResponse,
                    style:
                        const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
            if (isSuccess)
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx); // Close dialog

                  // Navigate to dashboard
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DashboardScreen(userName: username),
                    ),
                  );
                },
                child: const Text('Go to Dashboard'),
              ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Request error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void handleButtonPress() {
    if (!isClientCodeValid) {
      checkClientCode();
    } else {
      login();
    }
  }

  // Add debug button to UI
  Widget _buildDebugButton() {
    return TextButton(
      onPressed: () {
        if (isClientCodeValid) {
          _showRawApiRequestInfo();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please verify client code first'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      },
      child: const Text('DEBUG API'),
      style: TextButton.styleFrom(
        foregroundColor: Colors.red,
      ),
    );
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
      body: Center(
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
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      prefixIcon: Icon(Icons.lock),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Remember Me', style: TextStyle(fontSize: 16)),
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
                // Direct API Login button for testing
                if (showLoginFields)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _ensureProperLoginRequest,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
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
                      child: const Text('DIRECT API LOGIN'),
                    ),
                  ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: _buildDebugButton(),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Debug Info'),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  'Current API URL: ${clientApiUrl ?? "Not Set"}'),
                              const SizedBox(height: 8),
                              Text(
                                  'Client Code: ${_clientCodeController.text}'),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: () async {
                                  Navigator.pop(ctx);
                                  if (clientApiUrl != null) {
                                    // Store API URL directly
                                    await ApiService.setApiUrl(clientApiUrl!);

                                    // Test connection
                                    final testResult =
                                        await _testLoginUrlAvailability();

                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(testResult
                                            ? 'Connection to login URL successful!'
                                            : 'Failed to connect to login URL'),
                                      ),
                                    );
                                  }
                                },
                                child: const Text('Test & Save URL'),
                              ),
                              const SizedBox(height: 8),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const ApiTestScreen(),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.indigo,
                                ),
                                child: const Text('Open API Testing Screen'),
                              ),
                              const SizedBox(height: 8),
                              ElevatedButton(
                                onPressed: () async {
                                  // Check if we have user and password
                                  if (_usernameController.text.isEmpty ||
                                      _passwordController.text.isEmpty) {
                                    Navigator.pop(ctx);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            'Please enter username and password first'),
                                        backgroundColor: Colors.orange,
                                      ),
                                    );
                                    return;
                                  }

                                  Navigator.pop(ctx);
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
                                    // Prepare raw request data for debugging
                                    String username =
                                        _usernameController.text.trim();
                                    String password = _passwordController.text;

                                    // Clean URL
                                    String cleanUrl = clientApiUrl!;
                                    if (cleanUrl.endsWith('/')) {
                                      cleanUrl = cleanUrl.substring(
                                          0, cleanUrl.length - 1);
                                    }

                                    // Create login URL
                                    final loginUrl = '$cleanUrl/api/login';

                                    // Create request body
                                    final Map<String, dynamic> requestBody = {
                                      'username': username,
                                      'password': password,
                                    };

                                    // JSON encode the request body
                                    final String jsonBody =
                                        jsonEncode(requestBody);

                                    if (!mounted) return;
                                    Navigator.pop(context); // Close loading

                                    // Show raw request dialog
                                    showDialog(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text('Raw API Request'),
                                        content: SingleChildScrollView(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                  'Login Request Details:',
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold)),
                                              const SizedBox(height: 8),
                                              Text('URL: $loginUrl'),
                                              const SizedBox(height: 8),
                                              const Text('Headers:',
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold)),
                                              const Text(
                                                  'Content-Type: application/json'),
                                              const SizedBox(height: 8),
                                              const Text('Body:',
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold)),
                                              Text(
                                                jsonBody,
                                                style: const TextStyle(
                                                  fontFamily: 'monospace',
                                                  fontSize: 12,
                                                ),
                                              ),
                                              const Divider(),
                                              const Text('Body Keys:',
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold)),
                                              Text(requestBody.keys.join(', ')),
                                              const SizedBox(height: 8),
                                              const Text('Body Values:',
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold)),
                                              Text('username: $username'),
                                              Text(
                                                  'password: ${password.replaceAll(RegExp(r'.'), '*')}'),
                                              const Divider(),
                                              const Text('Send API Request?'),
                                            ],
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(ctx),
                                            child: const Text('Cancel'),
                                          ),
                                          TextButton(
                                            onPressed: () async {
                                              Navigator.pop(ctx);

                                              // Show loading indicator
                                              showDialog(
                                                context: context,
                                                barrierDismissible: false,
                                                builder:
                                                    (BuildContext context) {
                                                  return const Center(
                                                    child:
                                                        CircularProgressIndicator(),
                                                  );
                                                },
                                              );

                                              try {
                                                // Send direct HTTP request
                                                final response = await http
                                                    .post(
                                                      Uri.parse(loginUrl),
                                                      headers: {
                                                        'Content-Type':
                                                            'application/json'
                                                      },
                                                      body: jsonBody,
                                                    )
                                                    .timeout(const Duration(
                                                        seconds: 10));

                                                if (!mounted) return;
                                                Navigator.pop(
                                                    context); // Close loading

                                                // Format response for display
                                                String formattedResponse = '';
                                                bool isJsonResponse = true;
                                                Map<String, dynamic>
                                                    responseData = {};

                                                try {
                                                  responseData = json
                                                      .decode(response.body);
                                                  formattedResponse =
                                                      const JsonEncoder
                                                              .withIndent('  ')
                                                          .convert(
                                                              responseData);
                                                } catch (e) {
                                                  isJsonResponse = false;
                                                  formattedResponse =
                                                      response.body;
                                                }

                                                // Show response dialog
                                                showDialog(
                                                  context: context,
                                                  builder: (ctx) => AlertDialog(
                                                    title: Text(
                                                        'API Response (${response.statusCode})'),
                                                    content:
                                                        SingleChildScrollView(
                                                      child: Column(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                            'Status Code: ${response.statusCode}',
                                                            style: TextStyle(
                                                              color: response
                                                                          .statusCode <
                                                                      400
                                                                  ? Colors.green
                                                                  : Colors.red,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                              height: 8),
                                                          const Text(
                                                              'Response Body:',
                                                              style: TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold)),
                                                          const SizedBox(
                                                              height: 4),
                                                          Container(
                                                            padding:
                                                                const EdgeInsets
                                                                    .all(8),
                                                            decoration:
                                                                BoxDecoration(
                                                              color: Colors.grey
                                                                  .shade100,
                                                              border: Border.all(
                                                                  color: Colors
                                                                      .grey
                                                                      .shade300),
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          4),
                                                            ),
                                                            child:
                                                                SelectableText(
                                                              formattedResponse,
                                                              style:
                                                                  const TextStyle(
                                                                fontFamily:
                                                                    'monospace',
                                                                fontSize: 12,
                                                              ),
                                                            ),
                                                          ),
                                                          if (isJsonResponse) ...[
                                                            const SizedBox(
                                                                height: 8),
                                                            const Text(
                                                                'Response Keys:',
                                                                style: TextStyle(
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold)),
                                                            Text(responseData
                                                                .keys
                                                                .join(', ')),
                                                          ],
                                                          const SizedBox(
                                                              height: 16),
                                                          Text(
                                                            'Login Result: ${isJsonResponse && responseData.containsKey("success") && responseData["success"] == true ? "Success ✅" : "Failed ❌"}',
                                                            style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              color: isJsonResponse &&
                                                                      responseData
                                                                          .containsKey(
                                                                              "success") &&
                                                                      responseData[
                                                                              "success"] ==
                                                                          true
                                                                  ? Colors.green
                                                                  : Colors.red,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    actions: [
                                                      TextButton(
                                                        onPressed: () =>
                                                            Navigator.pop(ctx),
                                                        child:
                                                            const Text('Close'),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              } catch (e) {
                                                if (!mounted) return;
                                                Navigator.pop(
                                                    context); // Close loading

                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                        'Request error: ${e.toString()}'),
                                                    backgroundColor: Colors.red,
                                                  ),
                                                );
                                              }
                                            },
                                            child: const Text('Send Request'),
                                          ),
                                        ],
                                      ),
                                    );
                                  } catch (e) {
                                    if (!mounted) return;
                                    Navigator.pop(context); // Close loading
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Error: ${e.toString()}'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.deepOrange,
                                ),
                                child: const Text('Raw API Request Test'),
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
                    },
                    child: const Text('Show API URL (Debug)'),
                  ),
                ),
              ],
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

      print('⚠️ TEST LOGIN: API URL=$apiUrl, Username=$username');

      // Clean URL by removing trailing slash if present
      String cleanUrl = apiUrl;
      if (cleanUrl.endsWith('/')) {
        cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
      }

      // Create the login URL
      final loginUrl = '$cleanUrl/api/login';
      print('⚠️ TEST LOGIN URL: $loginUrl');

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

      print('⚠️ TEST LOGIN response code: ${response.statusCode}');
      print('⚠️ TEST LOGIN response body: ${response.body}');

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
      body: SingleChildScrollView(
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
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'Password',
              ),
              obscureText: true,
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
