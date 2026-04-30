import 'dart:io';

class DebugHttpOverrides extends HttpOverrides {
  final bool allowBadCert;
  DebugHttpOverrides({this.allowBadCert = false});

  // Domains that belong to the app's own API server.
  // Certificate errors for these hosts are accepted so that devices whose
  // system trust-store doesn't carry the server's CA can still connect.
  static const _trustedHosts = ['att.easytimeonline.in'];

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.badCertificateCallback =
        (X509Certificate cert, String host, int port) {
      // Always accept certs for the app's own API server.
      if (_trustedHosts.any((h) => host == h || host.endsWith('.$h'))) {
        return true;
      }
      // In debug mode accept everything else too (development convenience).
      return allowBadCert;
    };
    return client;
  }
}
