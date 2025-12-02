import '../core/models.dart';

/// Impact score type for SWIP (Synheart Wearable Impact Protocol) hooks
typedef ImpactScore = double;

/// Abstract class for SWIP hooks to measure impact of partner app sessions
///
/// Implement this class to provide custom impact scoring logic based on
/// wearable metrics before, during, and after a session.
abstract class SwipHooks {
  /// Called when a partner app experiences a measurable session.
  Future<ImpactScore> onSessionSummary({
    required WearMetrics before,
    required WearMetrics during,
    required WearMetrics after,
    Map<String, Object?> context = const {},
  });
}
