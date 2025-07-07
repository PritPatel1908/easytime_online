import 'dart:convert';
import 'dart:io';

import 'package:easytime_online/client_codes_fetch_api.dart';
import 'package:easytime_online/dashboard_screen.dart';
import 'package:easytime_online/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'dart:io' show Platform;
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
        cardTheme: CardTheme(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade100),
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
          thumbColor: MaterialStateProperty.all(Colors.grey.shade300),
          thickness: MaterialStateProperty.all(4),
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

    if (savedCode != null) {
      setState(() {
        _clientCodeController.text = savedCode;
        isClientCodeValid = true;
        showLoginFields = true;
        buttonText = 'LOGIN';
      });

      // Try to verify client code with new API
      try {
        final response = await http.post(
          Uri.parse('http://10.251.246.37:81/api/verify-client-code'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'client_code': savedCode}),
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);

          // Extract the API URL from the response
          String baseApiUrl;
          if (data.containsKey('api_url')) {
            baseApiUrl = data['api_url'];
          } else if (data.containsKey('url')) {
            baseApiUrl = data['url'];
          } else {
            // If neither field exists, use default
            baseApiUrl = 'http://10.251.246.37:81';
          }

          // Remove trailing slash if present
          if (baseApiUrl.endsWith('/')) {
            baseApiUrl = baseApiUrl.substring(0, baseApiUrl.length - 1);
          }

          setState(() {
            clientApiUrl = baseApiUrl;
          });

          // Update the stored base URL
          await prefs.setString('base_api_url', baseApiUrl);
        } else if (savedBaseApiUrl != null) {
          // Use previously saved base URL if available
          setState(() {
            clientApiUrl = savedBaseApiUrl;
          });
        }
      } catch (e) {
        // Fallback to saved base URL or default if verification fails
        if (savedBaseApiUrl != null) {
          setState(() {
            clientApiUrl = savedBaseApiUrl;
          });
        } else {
          setState(() {
            clientApiUrl = 'http://10.251.246.37:81';
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

    setState(() {
      _clientCodeController.clear();
      _usernameController.clear();
      _passwordController.clear();
      isClientCodeValid = false;
      showLoginFields = false;
      buttonText = 'CHECK';
    });
  }

  void checkClientCode() async {
    String enteredCode = _clientCodeController.text.trim();
    final BuildContext currentContext = context;

    try {
      // Direct API call to verify client code
      final response = await http.post(
        Uri.parse('http://10.251.246.37:81/api/verify-client-code'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'client_code': enteredCode}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Extract the API URL from the response
        String baseApiUrl;
        if (data.containsKey('api_url')) {
          baseApiUrl = data['api_url'];
        } else if (data.containsKey('url')) {
          baseApiUrl = data['url'];
        } else {
          // If neither field exists, use default
          baseApiUrl = 'http://10.251.246.37:81';
        }

        // Remove trailing slash if present
        if (baseApiUrl.endsWith('/')) {
          baseApiUrl = baseApiUrl.substring(0, baseApiUrl.length - 1);
        }

        // Store the base API URL without the /api/login suffix
        setState(() {
          isClientCodeValid = true;
          showLoginFields = true;
          buttonText = 'LOGIN';
          clientApiUrl = baseApiUrl;
        });

        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('client_code', enteredCode);
        await prefs.setString('base_api_url', baseApiUrl);
      } else {
        ScaffoldMessenger.of(currentContext).showSnackBar(
          const SnackBar(content: Text('Error: Invalid Client Code')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(currentContext).showSnackBar(
        const SnackBar(content: Text('Error: Could not verify Client Code')),
      );
    }
  }

  void login() async {
    String username = _usernameController.text.trim();
    String password = _passwordController.text;
    final BuildContext currentContext = context;

    // Validation checks
    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(
        currentContext,
      ).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
      return;
    }

    if (clientApiUrl == null) {
      ScaffoldMessenger.of(
        currentContext,
      ).showSnackBar(const SnackBar(content: Text('Client URL not found')));
      return;
    }

    try {
      // Append /api/login to the base URL for the login endpoint
      final loginUrl = '$clientApiUrl/api/login';

      // Send login request to API
      final response = await http.post(
        Uri.parse(loginUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        SharedPreferences prefs = await SharedPreferences.getInstance();
        if (rememberMe) {
          await prefs.setString('user_code', username);
          await prefs.setString('user_password', password);
          await prefs.setBool('remember_me', rememberMe);
        } else {
          await prefs.remove('user_code');
          await prefs.remove('user_password');
          await prefs.remove('remember_me');
        }

        Navigator.pushReplacement(
          currentContext,
          MaterialPageRoute(
            builder: (context) => DashboardScreen(userName: username),
          ),
        );
      } else {
        final data = json.decode(response.body);

        ScaffoldMessenger.of(currentContext).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'Login failed')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(currentContext).showSnackBar(
        const SnackBar(
          content: Text('Error: Login failed. Please check your connection.'),
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
