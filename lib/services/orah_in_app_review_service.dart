import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

const int _reviewMilestoneNoteCount = 5;

// Update this value when the app's major version changes (for example, 1 -> 2).
const int _majorAppVersion = 1;

/// Counts newly created notes and requests an in-app review at the fifth note,
/// at most once for each major app version. All errors are intentionally silent.
Future<void> checkAndRequestReview() async {
  try {
    final preferences = await SharedPreferences.getInstance();
    final noteCount = (preferences.getInt('orah_created_note_count') ?? 0) + 1;
    await preferences.setInt('orah_created_note_count', noteCount);

    if (noteCount != _reviewMilestoneNoteCount) return;

    final requestedVersion =
        preferences.getInt('orah_review_requested_major_version');
    if (requestedVersion == _majorAppVersion) return;

    // Persist before invoking the platform API to prevent duplicate requests.
    await preferences.setInt(
      'orah_review_requested_major_version',
      _majorAppVersion,
    );
    await InAppReview.instance.requestReview();
  } catch (_) {
    // Reviews are optional; never interrupt or surface errors during note saving.
  }
}
