import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:kumoriya_core/kumoriya_core.dart';

import '../errors/anilist_error.dart';

abstract interface class AnilistGraphqlClient {
  Future<Result<Map<String, dynamic>, KumoriyaError>> execute({
    required String query,
    Map<String, dynamic> variables,
  });
}

final class HttpAnilistGraphqlClient implements AnilistGraphqlClient {
  HttpAnilistGraphqlClient({http.Client? httpClient, Uri? endpoint})
    : _httpClient = httpClient ?? http.Client(),
      _endpoint = endpoint ?? Uri.parse('https://graphql.anilist.co');

  final http.Client _httpClient;
  final Uri _endpoint;

  @override
  Future<Result<Map<String, dynamic>, KumoriyaError>> execute({
    required String query,
    Map<String, dynamic> variables = const <String, dynamic>{},
  }) async {
    try {
      final response = await _httpClient.post(
        _endpoint,
        headers: const <String, String>{
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(<String, dynamic>{
          'query': query,
          'variables': variables,
        }),
      );

      if (response.statusCode != 200) {
        return Failure(
          AnilistTransportError(
            message: 'AniList returned status ${response.statusCode}',
            statusCode: response.statusCode,
          ),
        );
      }

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) {
        return const Failure(
          AnilistMappingError(
            message: 'AniList response is not a JSON object.',
          ),
        );
      }

      final errors = decoded['errors'];
      if (errors is List && errors.isNotEmpty) {
        final first = errors.first;
        final message =
            first is Map<String, dynamic> && first['message'] is String
            ? first['message'] as String
            : 'AniList returned an unknown GraphQL error.';

        return Failure(AnilistUnexpectedError(message: message));
      }

      final data = decoded['data'];
      if (data is! Map<String, dynamic>) {
        return const Failure(
          AnilistMappingError(
            message: 'AniList payload does not contain data.',
          ),
        );
      }

      return Success(data);
    } on FormatException catch (error) {
      return Failure(
        AnilistMappingError(
          message: 'AniList response could not be decoded: $error',
        ),
      );
    } catch (error) {
      return Failure(
        AnilistTransportError(message: 'AniList request failed: $error'),
      );
    }
  }
}
