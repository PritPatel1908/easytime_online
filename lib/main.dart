import 'dart:convert';
import 'package:easytime_online/client_codes_fetch_api.dart';
import 'package:easytime_online/dashboard_screen.dart';
import 'package:easytime_online/splash_screen.dart';
import 'package:easytime_online/main_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async'; // Added for Timer
import 'package:flutter/foundation.dart'; // Added for kDebugMode

// Utility class to hide system navigation bar
class SystemUIUtil {
  static Timer? _autoHideTimer;
  static bool _isListenerSetup = false;
  static DateTime? _lastVisibilityChange;

  static void hideSystemNavigationBar() {
    // Use immersiveSticky mode which allows the user to swipe to reveal the navigation bar
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
    );

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
      systemNavigationBarDividerColor: Colors.transparent,
    ));

    // Set up an observer for system UI visibility changes
    if (!_isListenerSetup) {
      _setupVisibilityObserver();
      _isListenerSetup = true;
    }
  }

  static void checkAndHideNavigationBarIfNeeded() {
    // If it's been more than 4.5 seconds since the last visibility change,
    // ensure the navigation bar is hidden
    if (_lastVisibilityChange != null) {
      final now = DateTime.now();
      final difference = now.difference(_lastVisibilityChange!);
      if (difference.inMilliseconds > 4500) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      }
    }
  }

  static void _setupVisibilityObserver() {
    // Add a listener to detect when the system UI becomes visible
    SystemChannels.system.setMessageHandler((message) async {
      if (message is Map<dynamic, dynamic>) {
        if (message.containsKey('type') &&
            message['type'] == 'SystemUiVisibilityChange') {
          if (message.containsKey('visible') && message['visible'] == true) {
            // Record when the visibility changed
            _lastVisibilityChange = DateTime.now();

            // System UI became visible, set timer to hide it after 4.5 seconds
            _autoHideTimer?.cancel();
            _autoHideTimer = Timer(const Duration(milliseconds: 4500), () {
              SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
            });
          }
        }
      }
      return null;
    });
  }
}

// Observer to ensure system UI stays as configured
class SystemUIObserver with WidgetsBindingObserver {
  SystemUIObserver() {
    WidgetsBinding.instance.addObserver(this);
    SystemUIUtil.hideSystemNavigationBar();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      SystemUIUtil.hideSystemNavigationBar();
    }
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientations
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Hide system navigation bar
  SystemUIUtil.hideSystemNavigationBar();

  // Create the observer
  final systemUIObserver = SystemUIObserver();

  // Set up a periodic check to ensure navigation bar stays hidden
  Timer.periodic(const Duration(seconds: 2), (_) {
    SystemUIUtil.checkAndHideNavigationBarIfNeeded();
  });

  runApp(MyApp(systemUIObserver: systemUIObserver));
}

class MyApp extends StatelessWidget {
  final SystemUIObserver systemUIObserver;

  const MyApp({super.key, required this.systemUIObserver});

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
        // Custom page transitions for smooth navigation
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: ZoomPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
            TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
            TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
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
        // Ensure system UI settings are maintained throughout the app
        SystemUIUtil.hideSystemNavigationBar();

        // Global scrolling behavior with system UI control
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarIconBrightness: Brightness.dark,
            systemNavigationBarDividerColor: Colors.transparent,
          ),
          child: ScrollConfiguration(
            behavior: const ScrollBehavior().copyWith(
              physics: const ClampingScrollPhysics(),
              overscroll: false,
            ),
            child: child!,
          ),
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

    // Ensure system UI settings are maintained
    SystemUIUtil.hideSystemNavigationBar();

    _loadSavedClientCode();
  }

  @override
  void dispose() {
    _clientCodeController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
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

  Future<void> checkClientCode() async {
    // Dismiss keyboard
    FocusScope.of(context).unfocus();

    String enteredCode = _clientCodeController.text.trim();
    if (enteredCode.isEmpty) {
      _showCustomToast('Please enter client code', isSuccess: false);
      return;
    }

    // Store context before async gap
    final BuildContext currentContext = context;

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

        if (!mounted) return;
        if (!isLoginUrlAccessible) {
          _safelyShowToast(
            'Warning: Login server might not be accessible. Check your connection.',
            isSuccess: false,
          );
        }
      } else {
        if (!mounted) return;
        _safelyShowToast(
          result['message'] ?? 'Invalid client code',
          isSuccess: false,
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(currentContext); // Close loading dialog
      _safelyShowToast('Error: ${e.toString()}', isSuccess: false);
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

    // Store context before async gap
    final BuildContext currentContext = context;

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

      Navigator.pop(currentContext); // Close loading

      // Process result
      final bool loginSuccess = result['success'] == true;
      final String message = result['message'] ??
          (loginSuccess ? 'Login successful' : 'Login failed');

      // Show better styled toast message
      _safelyShowToast(message, isSuccess: loginSuccess);

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

        // Debug print to see if userData contains emp_key
        if (kDebugMode) {
          print("DEBUG - userData extracted: $userData");
        }

        // Ensure emp_key is set (handle different API response formats)
        String? empKey;

        // Try to extract emp_key from different locations
        if (userData.containsKey('emp_key')) {
          empKey = userData['emp_key']?.toString();
        } else if (result['response_data'].containsKey('emp_key')) {
          empKey = result['response_data']['emp_key']?.toString();
        } else if (result.containsKey('emp_key')) {
          empKey = result['emp_key']?.toString();
        }

        // If we still don't have emp_key, try to find it recursively
        if (empKey == null || empKey.isEmpty) {
          empKey = _findEmpKeyRecursively(result);
        }

        // If we still don't have emp_key, use a default for testing
        if (empKey == null || empKey.isEmpty) {
          // WARNING: Only for development!
          empKey = "1234"; // Replace with your actual test emp_key if needed
          if (kDebugMode) {
            print("WARNING: Using default emp_key for testing: $empKey");
          }
        }

        if (kDebugMode) {
          print("DEBUG - Final empKey to use: $empKey");
        }

        // Ensure userData has emp_key explicitly set
        userData['emp_key'] = empKey;

        // Navigate to dashboard using helper method
        _navigateToDashboardAfterDelay(
            currentContext, userData['emp_name'] ?? username, userData);
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(currentContext); // Close loading dialog

      // Show error toast
      _safelyShowToast('Login error: ${e.toString()}', isSuccess: false);
    }
  }

  // Helper method to safely show toast message after async operations
  void _safelyShowToast(String message, {required bool isSuccess}) {
    if (mounted) {
      _showCustomToast(message, isSuccess: isSuccess);
    }
  }

  // Simple toast message
  void _showCustomToast(String message, {required bool isSuccess}) {
    // Only proceed if the widget is still mounted
    if (!mounted) return;

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

  // Helper method to navigate to dashboard after delay
  void _navigateToDashboardAfterDelay(BuildContext contextToUse,
      String displayName, Map<String, dynamic> userData) {
    // Store a reference to the context
    final BuildContext localContext = contextToUse;

    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      Navigator.pushReplacement(
        localContext,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => MainNavigation(
            userName: displayName,
            userData: userData,
            empKey: userData['emp_key'] ?? '',
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(0.0, 0.3);
            const end = Offset.zero;
            const curve = Curves.easeOut;
            var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
            var offsetAnimation = animation.drive(tween);
            return SlideTransition(
              position: offsetAnimation,
              child: FadeTransition(opacity: animation, child: child),
            );
          },
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    });
  }

  // Helper method to safely navigate to dashboard
  // void ___safelyNavigateToDashboard(BuildContext contextToUse, String userName,
  //     Map<String, dynamic> userData) {
  //   if (mounted) {
  //     Navigator.pushReplacement(
  //       contextToUse,
  //       MaterialPageRoute(
  //         builder: (context) => DashboardScreen(
  //           userName: userName,
  //           userData: userData,
  //         ),
  //       ),
  //     );
  //   }
  // }

  // Function to display raw request/response information for debugging
  // Removed to fix unused element warning
  // void ___showRawApiRequestInfo() {
  //   String username = _usernameController.text.trim();
  //   String password = _passwordController.text;
  //
  //   if (username.isEmpty || password.isEmpty) {
  //     _showCustomToast('Please enter username and password', isSuccess: false);
  //     return;
  //   }
  //
  //   if (clientApiUrl == null || clientApiUrl!.isEmpty) {
  //     _showCustomToast('API URL not set. Please verify client code',
  //         isSuccess: false);
  //     return;
  //   }
  //
  //   // Clean URL
  //   String cleanUrl = clientApiUrl!;
  //   if (cleanUrl.endsWith('/')) {
  //     cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
  //   }
  //
  //   // Create login URL
  //   final loginUrl = '$cleanUrl/api/login';
  //
  //   // Create raw request body
  //   final Map<String, dynamic> requestBody = {
  //     'username': username,
  //     'password': password,
  //   };
  //
  //   // JSON encode request body
  //   final String jsonRequestBody = jsonEncode(requestBody);
  //
  //   // Store context before async gap
  //   final BuildContext currentContext = context;
  //
  //   // Verify proper JSON encoding
  //   showDialog(
  //     context: currentContext,
  //     builder: (ctx) => AlertDialog(
  //       title: const Text('API Request Information'),
  //       content: SingleChildScrollView(
  //         child: Column(
  //           mainAxisSize: MainAxisSize.min,
  //           crossAxisAlignment: CrossAxisAlignment.start,
  //           children: [
  //             const Text('Raw Request Information:',
  //                 style: TextStyle(fontWeight: FontWeight.bold)),
  //             const SizedBox(height: 8),
  //             Text('URL: $loginUrl'),
  //             const SizedBox(height: 4),
  //             const Text('Headers:'),
  //             const Text('  Content-Type: application/json'),
  //             const Text('  Accept: application/json'),
  //             const SizedBox(height: 4),
  //             const Text('JSON Body:'),
  //             Container(
  //               width: double.infinity,
  //               padding: const EdgeInsets.all(8),
  //               margin: const EdgeInsets.symmetric(vertical: 4),
  //               decoration: BoxDecoration(
  //                 color: Colors.grey.shade100,
  //                 border: Border.all(color: Colors.grey.shade300),
  //                 borderRadius: BorderRadius.circular(4),
  //               ),
  //               child: Text(
  //                 jsonRequestBody,
  //                 style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
  //               ),
  //             ),
  //             const SizedBox(height: 4),
  //             Text('Body Keys: ${requestBody.keys.toList()}'),
  //             Text('Contains username: ${jsonRequestBody.contains(username)}'),
  //             Text('Contains password: ${jsonRequestBody.contains(password)}'),
  //             const SizedBox(height: 8),
  //             const Text('Send this request to the API?'),
  //           ],
  //         ),
  //       ),
  //       actions: [
  //         TextButton(
  //           onPressed: () => Navigator.pop(ctx),
  //           child: const Text('Cancel'),
  //         ),
  //         TextButton(
  //           onPressed: () {
  //             Navigator.pop(ctx);
  //             _sendRawApiRequest(loginUrl, jsonRequestBody);
  //           },
  //           child: const Text('Send Request'),
  //         ),
  //       ],
  //     ),
  //   );
  // }

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

  // Method removed to fix unused element warning

  // Method removed to fix unused element warning

  // Method removed to fix unused element warning

  // Execute PHP API login with detailed response
  // Removed to fix unused element warning
  // void ___executePhpApiLogin(
  //     String apiUrl, String username, String password) async {
  //   // Dismiss keyboard
  //   FocusScope.of(context).unfocus();
  //
  //   // Store context before async gap
  //   final BuildContext currentContext = context;
  //
  //   // Show loading indicator
  //   setState(() {
  //     buttonText = 'SENDING...';
  //   });
  //
  //   try {
  //     // Call our new PHP API login method
  //     final result =
  //         await ApiService.loginWithPhpApi(apiUrl, username, password);
  //
  //     if (!mounted) return;
  //
  //     setState(() {
  //       buttonText = 'LOGIN';
  //     });
  //
  //     // Determine if login was successful
  //     bool isSuccess = result['success'] == true;
  //     String message = result['message'] ?? 'Unknown response';
  //
  //     // Show toast message
  //     _safelyShowToast(message, isSuccess: isSuccess);
  //
  //     // If login successful, navigate to dashboard after a short delay
  //     if (isSuccess) {
  //       // Extract user data from response
  //       Map<String, dynamic> userData = {};
  //       if (result['response_data'].containsKey('user_data')) {
  //         userData = result['response_data']['user_data'];
  //       }
  //
  //       // Debug print to see if userData contains emp_key
  //       if (kDebugMode) {
  //         print("DEBUG - userData extracted: $userData");
  //       }
  //
  //       // Ensure emp_key is set (handle different API response formats)
  //       String? empKey;
  //
  //       // Try to extract emp_key from different locations
  //       if (userData.containsKey('emp_key')) {
  //         empKey = userData['emp_key']?.toString();
  //       } else if (result['response_data'].containsKey('emp_key')) {
  //         empKey = result['response_data']['emp_key']?.toString();
  //       } else if (result.containsKey('emp_key')) {
  //         empKey = result['emp_key']?.toString();
  //       }
  //
  //       // If we still don't have emp_key, try to find it recursively
  //       if (empKey == null || empKey.isEmpty) {
  //         empKey = _findEmpKeyRecursively(result);
  //       }
  //
  //       // If we still don't have emp_key, use a default for testing
  //       if (empKey == null || empKey.isEmpty) {
  //         // WARNING: Only for development!
  //         empKey = "1234"; // Replace with your actual test emp_key if needed
  //         if (kDebugMode) {
  //           print("WARNING: Using default emp_key for testing: $empKey");
  //         }
  //       }
  //
  //       if (kDebugMode) {
  //         print("DEBUG - Final empKey to use: $empKey");
  //       }
  //
  //       // Ensure userData has emp_key explicitly set
  //       userData['emp_key'] = empKey;
  //
  //       // Navigate to dashboard
  //       _navigateToDashboardAfterDelay(
  //         currentContext,
  //         userData['emp_name'] ?? username,
  //         {
  //           'user_data': userData,
  //           'emp_key': empKey, // Add explicit emp_key at top level
  //         },
  //       );
  //     }
  //   } catch (e) {
  //     if (!mounted) return;
  //
  //     setState(() {
  //       buttonText = 'LOGIN';
  //     });
  //     _safelyShowToast('Error: ${e.toString()}', isSuccess: false);
  //   }
  // }

  // Helper method to recursively find emp_key in a complex object
  String? _findEmpKeyRecursively(dynamic obj, [int depth = 0]) {
    // Prevent infinite recursion
    if (depth > 5) return null;

    if (obj is Map) {
      // Direct check for the key
      if (obj.containsKey('emp_key') && obj['emp_key'] != null) {
        return obj['emp_key'].toString();
      }

      // Check all keys that might be a variant of emp_key
      for (var key in obj.keys) {
        if (key is String &&
            (key.toLowerCase() == 'emp_key' ||
                key.toLowerCase() == 'empkey' ||
                key.toLowerCase() == 'employee_key')) {
          if (obj[key] != null) {
            return obj[key].toString();
          }
        }
      }

      // Check all map values recursively
      for (var value in obj.values) {
        if (value is Map || value is List) {
          final result = _findEmpKeyRecursively(value, depth + 1);
          if (result != null) return result;
        }
      }
    } else if (obj is List) {
      // Check all list items recursively
      for (var item in obj) {
        if (item is Map || item is List) {
          final result = _findEmpKeyRecursively(item, depth + 1);
          if (result != null) return result;
        }
      }
    }

    return null;
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

  // Method removed to fix unused element warning

  // Method to test all possible API request formats to find which one works
  // Removed to fix unused element warning
  // Future<void> ___runApiCompatibilityTest() async {
  //   if (clientApiUrl == null || clientApiUrl!.isEmpty) {
  //     _showCustomToast('Error: API URL not set', isSuccess: false);
  //     return;
  //   }
  //
  //   String username = _usernameController.text.trim();
  //   String password = _passwordController.text;
  //
  //   if (username.isEmpty || password.isEmpty) {
  //     _showCustomToast('Please enter username and password', isSuccess: false);
  //     return;
  //   }
  //
  //   // Dismiss keyboard
  //   FocusScope.of(context).unfocus();
  //
  //   // Store context before async gap
  //   final BuildContext currentContext = context;
  //
  //   // Show loading dialog
  //   showDialog(
  //     context: currentContext,
  //     barrierDismissible: false,
  //     builder: (BuildContext context) {
  //       return const Center(
  //         child: CircularProgressIndicator(),
  //       );
  //     },
  //   );
  //
  //   try {
  //     // Clean URL
  //     String cleanUrl = clientApiUrl!;
  //     if (cleanUrl.endsWith('/')) {
  //       cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
  //     }
  //
  //     // Create login URL
  //     final loginUrl = '$cleanUrl/api/login';
  //     final results = <String, Map<String, dynamic>>{};
  //
  //     // 1. Test standard JSON
  //     try {
  //       final jsonBody = jsonEncode({
  //         'username': username,
  //         'password': password,
  //       });
  //
  //       final response = await http
  //           .post(
  //             Uri.parse(loginUrl),
  //             headers: {
  //               'Content-Type': 'application/json',
  //               'Accept': 'application/json',
  //             },
  //             body: jsonBody,
  //           )
  //           .timeout(const Duration(seconds: 5));
  //
  //       results['JSON'] = {
  //         'status': response.statusCode,
  //         'body': response.body,
  //         'success': response.statusCode < 400,
  //       };
  //     } catch (e) {
  //       results['JSON'] = {
  //         'status': 'error',
  //         'body': e.toString(),
  //         'success': false,
  //       };
  //     }
  //
  //     // 2. Test form URL encoded
  //     try {
  //       final formBody =
  //           'username=${Uri.encodeComponent(username)}&password=${Uri.encodeComponent(password)}';
  //
  //       final response = await http
  //           .post(
  //             Uri.parse(loginUrl),
  //             headers: {
  //               'Content-Type': 'application/x-www-form-urlencoded',
  //               'Accept': 'application/json',
  //             },
  //             body: formBody,
  //           )
  //           .timeout(const Duration(seconds: 5));
  //
  //       results['Form-URL'] = {
  //         'status': response.statusCode,
  //         'body': response.body,
  //         'success': response.statusCode < 400,
  //       };
  //     } catch (e) {
  //       results['Form-URL'] = {
  //         'status': 'error',
  //         'body': e.toString(),
  //         'success': false,
  //       };
  //     }
  //
  //     // 3. Test multipart form
  //     try {
  //       final request = http.MultipartRequest('POST', Uri.parse(loginUrl));
  //       request.fields['username'] = username;
  //       request.fields['password'] = password;
  //
  //       final streamedResponse =
  //           await request.send().timeout(const Duration(seconds: 5));
  //       final response = await http.Response.fromStream(streamedResponse);
  //
  //       results['Multipart'] = {
  //         'status': response.statusCode,
  //         'body': response.body,
  //         'success': response.statusCode < 400,
  //       };
  //     } catch (e) {
  //       results['Multipart'] = {
  //         'status': 'error',
  //         'body': e.toString(),
  //         'success': false,
  //       };
  //     }
  //
  //     // 4. Test query parameters
  //     try {
  //       final queryUrl =
  //           '$loginUrl?username=${Uri.encodeComponent(username)}&password=${Uri.encodeComponent(password)}';
  //
  //       final response = await http.post(
  //         Uri.parse(queryUrl),
  //         headers: {'Accept': 'application/json'},
  //       ).timeout(const Duration(seconds: 5));
  //
  //       results['Query-Param'] = {
  //         'status': response.statusCode,
  //         'body': response.body,
  //         'success': response.statusCode < 400,
  //       };
  //     } catch (e) {
  //       results['Query-Param'] = {
  //         'status': 'error',
  //         'body': e.toString(),
  //         'success': false,
  //       };
  //     }
  //
  //     // 5. Test raw form parameters (no Content-Type)
  //     try {
  //       final formBody =
  //           'username=${Uri.encodeComponent(username)}&password=${Uri.encodeComponent(password)}';
  //
  //       final response = await http
  //           .post(
  //             Uri.parse(loginUrl),
  //             body: formBody,
  //           )
  //           .timeout(const Duration(seconds: 5));
  //
  //       results['Raw-Form'] = {
  //         'status': response.statusCode,
  //         'body': response.body,
  //         'success': response.statusCode < 400,
  //       };
  //     } catch (e) {
  //       results['Raw-Form'] = {
  //         'status': 'error',
  //         'body': e.toString(),
  //         'success': false,
  //       };
  //     }
  //
  //     if (!mounted) return;
  //     Navigator.pop(currentContext); // Close loading dialog
  //
  //     // Find the best working method
  //     final successMethods = results.entries
  //         .where((entry) => entry.value['success'] == true)
  //         .map((entry) => entry.key)
  //         .toList();
  //
  //     final recommended =
  //         successMethods.isNotEmpty ? successMethods.first : 'None';
  //
  //     // Show simplified results
  //     showDialog(
  //       context: currentContext,
  //       builder: (ctx) => AlertDialog(
  //         title: const Text('API Test Results'),
  //         content: Column(
  //           mainAxisSize: MainAxisSize.min,
  //           crossAxisAlignment: CrossAxisAlignment.start,
  //           children: [
  //             Text(
  //               'Working methods: ${successMethods.isEmpty ? "None" : successMethods.join(", ")}',
  //               style: TextStyle(
  //                 fontWeight: FontWeight.bold,
  //                 color: successMethods.isEmpty ? Colors.red : Colors.green,
  //               ),
  //             ),
  //             const SizedBox(height: 8),
  //             Text(
  //               'Recommended method: $recommended',
  //               style: const TextStyle(fontWeight: FontWeight.bold),
  //             ),
  //           ],
  //         ),
  //         actions: [
  //           TextButton(
  //             onPressed: () => Navigator.pop(ctx),
  //             child: const Text('Close'),
  //           ),
  //         ],
  //       ),
  //     );
  //   } catch (e) {
  //     if (!mounted) return;
  //     Navigator.pop(currentContext); // Close loading dialog
  //
  //     _showCustomToast('Error: ${e.toString()}', isSuccess: false);
  //   }
  // }

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
