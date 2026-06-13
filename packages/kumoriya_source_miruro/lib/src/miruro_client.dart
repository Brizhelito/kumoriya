import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class MiruroClient {
  static const String _baseUrl = 'https://www.miruro.tv';
  static const String _envUrl = '$_baseUrl/env2.js';
  static const String _pipeUrl = '$_baseUrl/api/secure/pipe';

  final http.Client _httpClient;
  String? _obfKey;

  MiruroClient({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  Future<void> _fetchKey() async {
    final response = await _httpClient.get(Uri.parse(_envUrl));
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch env2.js: ${response.statusCode}');
    }

    final body = response.body;
    final jsonStrMatch = RegExp(r'JSON\.parse\("(.*?)"\)').firstMatch(body);
    if (jsonStrMatch != null) {
      final jsonStr = jsonStrMatch.group(1)!.replaceAll(r'\"', '"');
      final envData = jsonDecode(jsonStr);
      _obfKey = envData['VITE_PIPE_OBF_KEY'];
    }

    if (_obfKey == null) {
      throw Exception('Failed to extract VITE_PIPE_OBF_KEY from env2.js');
    }
  }

  List<int> _hexToBytes(String hex) {
    final bytes = <int>[];
    for (int i = 0; i < hex.length; i += 2) {
      bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return bytes;
  }

  List<int> _xor(List<int> data, List<int> key) {
    final result = List<int>.filled(data.length, 0);
    for (int i = 0; i < data.length; i++) {
      result[i] = data[i] ^ key[i % key.length];
    }
    return result;
  }

  Future<Map<String, dynamic>> pipeRequest(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    if (_obfKey == null) {
      await _fetchKey();
    }

    final payload = {
      'path': path,
      'method': 'GET',
      'query': query ?? {},
      'body': null,
      'version': '0.2.0',
    };

    final payloadJson = jsonEncode(payload);
    final payloadBase64 = base64Url
        .encode(utf8.encode(payloadJson))
        .replaceAll('=', '');

    final uri = Uri.parse('$_pipeUrl?e=$payloadBase64');

    var response = await _httpClient.get(
      uri,
      headers: {
        'Referer': 'https://www.miruro.tv/',
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      },
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Pipe request failed with status: ${response.statusCode}',
      );
    }

    try {
      return _decodeResponse(response.body);
    } catch (e) {
      // If decompression fails, maybe key rotated. Fetch key and retry once.
      await _fetchKey();
      response = await _httpClient.get(
        uri,
        headers: {
          'Referer': 'https://www.miruro.tv/',
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        },
      );

      if (response.statusCode != 200) {
        throw Exception(
          'Pipe request failed on retry with status: ${response.statusCode}',
        );
      }

      return _decodeResponse(response.body);
    }
  }

  Map<String, dynamic> _decodeResponse(String base64UrlData) {
    String normalized = base64UrlData;
    while (normalized.length % 4 != 0) {
      normalized += '=';
    }

    final encryptedBytes = base64Url.decode(normalized);
    final keyBytes = _hexToBytes(_obfKey!);

    final decryptedBytes = _xor(encryptedBytes, keyBytes);

    final decompressedBytes = gzip.decode(decryptedBytes);
    final jsonStr = utf8.decode(decompressedBytes);

    return jsonDecode(jsonStr);
  }
}
