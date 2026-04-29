import 'dart:io';

class DebugHttpOverrides extends HttpOverrides {
  final bool allowBadCert;
  DebugHttpOverrides({this.allowBadCert = false});

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    if (allowBadCert) {
      client.badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
    }
    return client;
  }
}
