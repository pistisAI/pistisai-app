/// Embodiment simulator scaffold (no hardware integration).
abstract class EmbodimentSimulator {
  Future<void> connect();
  Future<void> disconnect();
  Future<EmbodimentPose> getCurrentPose();
  Future<void> setPose(EmbodimentPose pose);
}

class EmbodimentPose {
  final double x;
  final double y;
  final double rotation;

  const EmbodimentPose({
    this.x = 0,
    this.y = 0,
    this.rotation = 0,
  });
}

class NoopEmbodimentSimulator implements EmbodimentSimulator {
  EmbodimentPose _pose = const EmbodimentPose();

  @override
  Future<void> connect() async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<EmbodimentPose> getCurrentPose() async => _pose;

  @override
  Future<void> setPose(EmbodimentPose pose) async {
    _pose = pose;
  }
}
