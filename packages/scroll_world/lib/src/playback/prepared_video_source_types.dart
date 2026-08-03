final class PreparedVideoSource {
  PreparedVideoSource(this.uri, this._release);

  final Uri uri;
  final void Function() _release;
  bool _released = false;

  void release() {
    if (_released) return;
    _released = true;
    _release();
  }
}
