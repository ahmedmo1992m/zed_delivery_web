import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ImageKitUtils {
  // المفاتيح بتاعتك اللي بعتَّهالي

  // يرجى تغيير "yourservice" إلى اسم الخدمة الخاص بك في ImageKit
  static const String _imageKitUrl =
      'https://upload.imagekit.io/api/v1/files/upload';

  static Future<String?> uploadImage(File file, String folder) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse(_imageKitUrl));

      request.fields['fileName'] = file.path.split('/').last;
      request.fields['folder'] = folder;
      // استخدام المفتاح الخاص في التوثيق

      request.files.add(await http.MultipartFile.fromPath('file', file.path));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return data['url'];
      } else {
        ('Error uploading image: ${response.body}');
        return null;
      }
    } catch (e) {
      ('Exception during image upload: $e');
      return null;
    }
  }
}
