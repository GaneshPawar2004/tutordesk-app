import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/app_state.dart';
import '../../data/models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// Lets the teacher take or choose a photo; returns a small JPEG (≈600 px),
/// or null if cancelled.
Future<List<int>?> pickStudentPhoto(BuildContext context) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Take photo'),
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Choose from gallery'),
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
        ],
      ),
    ),
  );
  if (source == null) return null;
  try {
    final file = await ImagePicker().pickImage(
      source: source,
      maxWidth: 600,
      maxHeight: 600,
      imageQuality: 70,
      preferredCameraDevice: CameraDevice.front,
    );
    return file == null ? null : await file.readAsBytes();
  } catch (e) {
    if (context.mounted) {
      showError(context, 'Could not open the camera/gallery.');
    }
    return null;
  }
}

/// Picks a photo and uploads it for [s]. True when saved.
Future<bool> changeStudentPhoto(BuildContext context, Student s) async {
  final bytes = await pickStudentPhoto(context);
  if (bytes == null || !context.mounted) return false;
  final ok = await runApi(context, () => appState.uploadStudentPhoto(s, bytes));
  if (ok && context.mounted) showSuccess(context, 'Photo saved');
  return ok;
}

/// The student's photo (or a person icon) in a circle.
class StudentPhoto extends StatelessWidget {
  const StudentPhoto({
    super.key,
    required this.student,
    this.radius = 32,
    this.background,
  });

  final Student? student;
  final double radius;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final s = student;
    final url = s == null ? null : appState.photoUrl(s);
    final bg =
        background ?? (s?.disabled ?? false ? Colors.grey : AppColors.primary);
    final icon = Icon(
      Icons.person_outline,
      color: Colors.white,
      size: radius * 0.95,
    );
    if (url == null) {
      return CircleAvatar(radius: radius, backgroundColor: bg, child: icon);
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: bg,
      child: ClipOval(
        child: Image.network(
          url,
          headers: appState.authHeaders,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => icon,
        ),
      ),
    );
  }
}

/// Large photo with Change / Remove buttons (actions dialog → View Photo).
Future<void> showStudentPhotoDialog(BuildContext context, Student s) {
  return showDialog(
    context: context,
    builder: (ctx) => ListenableBuilder(
      listenable: appState,
      builder: (ctx, _) {
        final hasPhoto = s.photoUpdatedAt != null;
        return AlertDialog(
          title: Text(s.name),
          content: Center(
            heightFactor: 1,
            child: StudentPhoto(student: s, radius: 100),
          ),
          actions: [
            if (hasPhoto)
              TextButton(
                onPressed: () async {
                  final ok = await confirmDialog(
                    ctx,
                    title: 'Remove photo?',
                    message: 'The photo of ${s.name} will be deleted.',
                    confirmLabel: 'REMOVE',
                  );
                  if (ok && ctx.mounted) {
                    await runApi(ctx, () => appState.removeStudentPhoto(s));
                  }
                },
                child: const Text(
                  'REMOVE',
                  style: TextStyle(color: AppColors.danger),
                ),
              ),
            TextButton(
              onPressed: () => changeStudentPhoto(ctx, s),
              child: Text(hasPhoto ? 'CHANGE' : 'ADD PHOTO'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('CLOSE'),
            ),
          ],
        );
      },
    ),
  );
}
