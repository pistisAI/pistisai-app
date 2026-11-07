/// Next visible text for one in-progress assistant message.
///
/// [incoming] is either a true delta or a harness snapshot of the same turn.
/// [replaces] means the harness rewrote the reply (the new text is not an
/// extension of [previous]) and [incoming] is the full snapshot.
///
/// A snapshot that still starts with [previous] is also a replacement, so a
/// poll that sends the whole reply does not concatenate onto itself.
String nextStreamingContent({
  required String previous,
  required String incoming,
  bool replaces = false,
}) {
  if (replaces) {
    return incoming.isEmpty ? previous : incoming;
  }
  if (incoming.isEmpty) return previous;
  if (previous.isNotEmpty && incoming.startsWith(previous)) {
    return incoming;
  }
  return previous + incoming;
}
