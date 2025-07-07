import 'dart:convert';
import 'package:http/http.dart' as http;

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
