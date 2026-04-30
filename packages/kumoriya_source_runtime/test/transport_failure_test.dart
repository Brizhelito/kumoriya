import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:kumoriya_source_runtime/kumoriya_source_runtime.dart';
import 'package:test/test.dart';

void main() {
  group('TransportFailure.classify', () {
    test('classifies SocketException as transport', () {
      expect(
        TransportFailure.classify(const SocketException('refused')),
        isTrue,
      );
    });

    test('classifies HttpException as transport', () {
      expect(
        TransportFailure.classify(const HttpException('connection reset')),
        isTrue,
      );
    });

    test('classifies TimeoutException as transport', () {
      expect(TransportFailure.classify(TimeoutException('idle')), isTrue);
    });

    test('classifies http.ClientException as transport', () {
      expect(
        TransportFailure.classify(http.ClientException('handshake failed')),
        isTrue,
      );
    });

    test('does not classify FormatException as transport', () {
      expect(
        TransportFailure.classify(const FormatException('bad json')),
        isFalse,
      );
    });

    test('does not classify StateError as transport', () {
      expect(TransportFailure.classify(StateError('bad state')), isFalse);
    });

    test('does not classify ArgumentError as transport', () {
      expect(TransportFailure.classify(ArgumentError('bad arg')), isFalse);
    });
  });
}
