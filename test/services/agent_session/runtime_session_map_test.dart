import 'package:flutter_test/flutter_test.dart';
import 'package:pistisai/services/agent_session/runtime_session_map.dart';

class _CountingStore extends InMemoryRuntimeSessionMapStore {
  int saves = 0;

  @override
  Future<void> save(Map<String, Map<String, String>> entries) {
    saves++;
    return super.save(entries);
  }
}

void main() {
  group('RuntimeSessionMap', () {
    test('a channel has no runtime session until one is bound', () async {
      final map =
          await RuntimeSessionMap.load(InMemoryRuntimeSessionMapStore());
      expect(map.runtimeSessionFor('direct', 'hermes'), isNull);
      expect(map.sessionsFor('direct'), isEmpty);
    });

    test('bind sets and replaces one harness id per channel', () async {
      final map =
          await RuntimeSessionMap.load(InMemoryRuntimeSessionMapStore());
      await map.bind('direct', 'hermes', 'run-a');
      await map.bind('direct', 'other', 'x-1');
      await map.bind('direct', 'hermes', 'run-b');
      expect(map.runtimeSessionFor('direct', 'hermes'), 'run-b');
      expect(map.sessionsFor('direct'), {'hermes': 'run-b', 'other': 'x-1'});
      expect(map.runtimeSessionFor('topic', 'hermes'), isNull);
    });

    test('clear removes one harness or the whole channel', () async {
      final map =
          await RuntimeSessionMap.load(InMemoryRuntimeSessionMapStore());
      await map.bind('direct', 'hermes', 'run-a');
      await map.bind('direct', 'other', 'x-1');
      await map.bind('topic', 'hermes', 'run-t');

      await map.clear('direct', harnessId: 'hermes');
      expect(map.runtimeSessionFor('direct', 'hermes'), isNull);
      expect(map.runtimeSessionFor('direct', 'other'), 'x-1');

      await map.clear('direct');
      expect(map.sessionsFor('direct'), isEmpty);
      expect(map.runtimeSessionFor('topic', 'hermes'), 'run-t');
    });

    test('mappings survive a reload through the injected store', () async {
      final store = InMemoryRuntimeSessionMapStore();
      final first = await RuntimeSessionMap.load(store);
      await first.bind('direct', 'hermes', 'run-a');
      await first.bind('topic', 'hermes', 'run-t');
      await first.clear('topic');

      final second = await RuntimeSessionMap.load(store);
      expect(second.runtimeSessionFor('direct', 'hermes'), 'run-a');
      expect(second.sessionsFor('topic'), isEmpty);
    });

    test('only writes to the store when something changed', () async {
      final store = _CountingStore();
      final map = await RuntimeSessionMap.load(store);
      await map.bind('direct', 'hermes', 'run-a');
      await map.bind('direct', 'hermes', 'run-a');
      await map.clear('missing');
      await map.clear('direct', harnessId: 'other');
      expect(store.saves, 1);
    });

    test('sessionsFor cannot be used to change the map', () async {
      final map =
          await RuntimeSessionMap.load(InMemoryRuntimeSessionMapStore());
      await map.bind('direct', 'hermes', 'run-a');
      expect(() => map.sessionsFor('direct')['hermes'] = 'forged',
          throwsUnsupportedError);
    });

    test('rejects empty ids', () async {
      final map =
          await RuntimeSessionMap.load(InMemoryRuntimeSessionMapStore());
      expect(() => map.bind('', 'hermes', 'run-a'), throwsArgumentError);
      expect(() => map.bind('direct', ' ', 'run-a'), throwsArgumentError);
      expect(() => map.bind('direct', 'hermes', ''), throwsArgumentError);
    });
  });
}
