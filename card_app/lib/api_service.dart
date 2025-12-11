import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'models.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // === 注意：真机调试时要将 IP 改为电脑的局域网 IP ===
  static const String baseUrl = 'http://127.0.0.1:5000/api'; 
  
  
  static String? _authToken;

  static bool get isLoggedIn => _authToken != null;

  // 初始化，尝试从本地存储加载 Token
  static Future<bool> init() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token != null) {
      _authToken = token;
      return true;
    }
    return false;
  }

  // 退出登录，同时清除本地 Token
  static Future<void> logout() async {
    _authToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  // 构造 Header，如果有 Token 则带上
  static Map<String, String> get _headers {
    final Map<String, String> headers = {'Content-Type': 'application/json'};
    if (_authToken != null) {
      headers['Authorization'] = 'Bearer $_authToken';
    }
    return headers;
  }

  // === 认证接口 ===
  // 登录成功后保存 Token 到本地存储
  static Future<bool> login(String username, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      _authToken = body['access_token'];
      // 保存到本地
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', _authToken!);
      return true;
    }
    return false;
  }

  static Future<String?> register(String username, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );
    if (response.statusCode == 201) {
      return null; // Success
    } else {
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      return body['error'] ?? '注册失败';
    }
  }

  // === 业务接口 ===

  static Future<List<CardModel>> fetchCards() async {
    try {
      print('Fetching cards from $baseUrl/cards...'); // 调试
      final response = await http.get(Uri.parse('$baseUrl/cards'), headers: _headers);
      
      print('Cards Response: ${response.statusCode}'); // 调试
      
      if (response.statusCode == 200) {
        final List<dynamic> body = jsonDecode(utf8.decode(response.bodyBytes));
        return body.map((item) => CardModel.fromJson(item)).toList();
      } else if (response.statusCode == 401) {
        throw Exception('AuthError');
      } else {
        print('Error Body: ${response.body}'); // 打印错误详情
        throw Exception('Load Failed: ${response.statusCode}');
      }
    } catch (e) {
      print('Fetch Cards Exception: $e'); // 关键：打印异常
      rethrow;
    }
  }

  static Future<void> createCard(CardModel card, List<String> imageFilenames) async {
    final Map<String, dynamic> data = card.toJson();
    data['image_paths'] = imageFilenames;
    
    // 调试
    print("Sending Create Card Request: $data");

    final response = await http.post(
      Uri.parse('$baseUrl/cards'), 
      headers: _headers, 
      body: jsonEncode(data)
    );

    // 调试
    print('Create Response: ${response.statusCode}');

    if (response.statusCode != 201) {
      print("Create Failed: ${response.body}");
      throw Exception('Create failed: ${response.body}');
    }
  }

  static Future<void> updateCard(int id, CardModel card, List<String>? imageFilenames) async {
    final Map<String, dynamic> data = card.toJson();
    if (imageFilenames != null) {
      data['image_paths'] = imageFilenames;
    }
    await http.put(
      Uri.parse('$baseUrl/cards/$id'),
      headers: _headers,
      body: jsonEncode(data),
    );
  }

  static Future<void> deleteCard(int id) async {
    await http.delete(Uri.parse('$baseUrl/cards/$id'), headers: _headers);
  }

  static Future<String?> uploadImage(XFile imageFile) async {
    var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/upload'));
    // 图片上传也可以带上 token（取决于后端是否严格校验，这里带上更保险）
    if (_authToken != null) {
      request.headers['Authorization'] = 'Bearer $_authToken';
    }
    
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
    try {
      final response = await http.get(Uri.parse('$baseUrl/meta'), headers: _headers);
      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      }
      print('Meta fetch failed: ${response.statusCode}');
      // 如果获取失败，不要返回空，临时返回默认值，防止 UI 崩溃
      return {
        'groups': ['默认清单 (本地)'], 
        'tags': []
      };
    } catch (e) {
      print('Fetch Meta Exception: $e');
      return {'groups': [], 'tags': []};
    }
  }

  static Future<void> updateMeta(List<String> groups, List<String> tags) async {
    await http.post(Uri.parse('$baseUrl/meta'), headers: _headers, body: jsonEncode({'groups': groups, 'tags': tags}));
  }

  static Future<void> deleteGroup(String groupName) async {
    await http.post(Uri.parse('$baseUrl/meta/delete_group'), headers: _headers, body: jsonEncode({'name': groupName}));
  }

  static Future<void> deleteTag(String tagName) async {
    await http.post(Uri.parse('$baseUrl/meta/delete_tag'), headers: _headers, body: jsonEncode({'name': tagName}));
  }
}