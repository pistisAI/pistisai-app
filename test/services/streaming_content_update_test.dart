import 'package:flutter_test/flutter_test.dart';
import 'package:pistisai/services/streaming_content_update.dart';

void main() {
  test('appends a true delta', () {
    expect(
      nextStreamingContent(previous: 'Hello', incoming: ' world'),
      'Hello world',
    );
  });

  test('a snapshot that extends the previous text replaces it', () {
    expect(
      nextStreamingContent(
        previous: 'Hello',
        incoming: 'Hello world',
      ),
      'Hello world',
    );
  });

  test('a non-prefix harness rewrite replaces only when asked', () {
    expect(
      nextStreamingContent(
        previous: 'short reply',
        incoming: 'a completely different long reply',
      ),
      'short replya completely different long reply',
    );
    expect(
      nextStreamingContent(
        previous: 'short reply',
        incoming: 'a completely different long reply',
        replaces: true,
      ),
      'a completely different long reply',
    );
  });

  test('an empty delta leaves the previous text', () {
    expect(
      nextStreamingContent(previous: 'Hello', incoming: ''),
      'Hello',
    );
  });
}
