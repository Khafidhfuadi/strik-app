import 'dart:io';
import 'package:home_widget/home_widget.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class HomeWidgetService {
  static const String appGroupId =
      'com.strik.strik_app.widget'; // Not used on Android but good practice
  static const String androidWidgetName = 'StoryWidgetProvider';

  static Future<void> updateWidget({
    required String title,
    required String subtitle,
    String? imageUrl,
  }) async {
    try {
      print("HomeWidgetService: Starting update for $title"); // LOG START
      // 1. Save Text Data
      await HomeWidget.saveWidgetData<String>('widget_title', title);
      await HomeWidget.saveWidgetData<String>('widget_subtitle', subtitle);
      print("HomeWidgetService: Text data saved");

      // 2. Download and Save Image if exists
      if (imageUrl != null) {
        print("HomeWidgetService: Downloading image from $imageUrl");
        final path = await _downloadImage(imageUrl);
        if (path != null) {
          await HomeWidget.saveWidgetData<String>('widget_image', path);
          print("HomeWidgetService: Image saved at $path");
        } else {
          print("HomeWidgetService: Failed to download image");
        }
      }

      // 3. Trigger Widget Update
      await HomeWidget.updateWidget(name: androidWidgetName);
      print("HomeWidgetService: Update request sent to Android");
    } catch (e) {
      print("Error updating HomeWidget: $e");
    }
  }

  static Future<String?> _downloadImage(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/widget_story_image.webp');
        await file.writeAsBytes(response.bodyBytes);
        return file.path;
      }
    } catch (e) {
      print("Error downloading widget image: $e");
    }
    return null;
  }
}
