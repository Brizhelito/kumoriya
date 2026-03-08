final class FakeClock {
  FakeClock(this._now);

  DateTime _now;

  DateTime now() => _now;

  void advance(Duration delta) {
    _now = _now.add(delta);
  }
}
