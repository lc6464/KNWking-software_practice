import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'models.dart';

class ApiService {
  static const String baseUrl = 'http://127.0.0.1:5000/api'; 

  static Future<List<CardModel>> fetchCards() async {
    final response = await http.get(Uri.parse('$baseUrl/cards'));
    if (response.statusCode == 200) {
      final List<dynamic> body = jsonDecode(utf8.decode(response.bodyBytes));
      return body.map((item) => CardModel.fromJson(item)).toList();
    } else {
      throw Exception('Load Failed');
    }
  }

  static Future<void> createCard(CardModel card, List<String> imageFilenames) async {
    final Map<String, dynamic> data = card.toJson();
    data['image_paths'] = imageFilenames;
    await http.post(Uri.parse('$baseUrl/cards'), headers: {'Content-Type': 'application/json'}, body: jsonEncode(data));
  }

  static Future<void> updateCard(int id, CardModel card, List<String> imageFilenames) async {
    final Map<String, dynamic> data = card.toJson();
    data['image_paths'] = imageFilenames;
    await http.put(Uri.parse('$baseUrl/cards/$id'), headers: {'Content-Type': 'application/json'}, body: jsonEncode(data));
  }

  static Future<void> deleteCard(int id) async {
    await http.delete(Uri.parse('$baseUrl/cards/$id'));
  }

  static Future<String?> uploadImage(XFile imageFile) async {
    var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/upload'));
    final bytes = await imageFile.readAsBytes();
    request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: imageFile.name));
    try {
      var res = await request.send();
      if (res.statusCode == 200) {
        final respStr = await res.stream.bytesToString();
        final json = jsonDecode(respStr);
        return json['filename'];
      }
    } catch (e) { print("上传失败: $e"); }
    return null;
  }

  static Future<Map<String, dynamic>> fetchMeta() async {
    final response = await http.get(Uri.parse('$baseUrl/meta'));
    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    }
    return {'groups': [], 'tags': []};
  }

  // 用于添加新项
  static Future<void> updateMeta(List<String> groups, List<String> tags) async {
    await http.post(Uri.parse('$baseUrl/meta'), headers: {'Content-Type': 'application/json'}, body: jsonEncode({'groups': groups, 'tags': tags}));
  }

  // === 新增：删除分组专用 ===
  static Future<void> deleteGroup(String groupName) async {
    await http.post(Uri.parse('$baseUrl/meta/delete_group'), headers: {'Content-Type': 'application/json'}, body: jsonEncode({'name': groupName}));
  }

  // === 新增：删除标签专用 ===
  static Future<void> deleteTag(String tagName) async {
    await http.post(Uri.parse('$baseUrl/meta/delete_tag'), headers: {'Content-Type': 'application/json'}, body: jsonEncode({'name': tagName}));
  }
}