import 'package:flutter/foundation.dart';

/// Base for the in-memory repositories used in the static UI phase.
///
/// Each repository owns its slice of mock data and reports mutations through
/// [changed]. Real repositories (backed by the future API) can replace these
/// without touching the screens.
abstract class MockRepository {
  MockRepository(this._onChanged);

  final VoidCallback _onChanged;

  @protected
  void changed() => _onChanged();
}
