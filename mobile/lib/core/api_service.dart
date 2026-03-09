import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/theme.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  late final Dio _dio;

  void init() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConstants.apiBaseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
    ));

    // Inject Firebase token on every request
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final token = await user.getIdToken();
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) {
        handler.next(error);
      },
    ));
  }

  // ── Auth ──────────────────────────────────────────────────
  Future<Map<String, dynamic>> getMe() async {
    final res = await _dio.get('/auth/me');
    return res.data;
  }

  // ── Plots ─────────────────────────────────────────────────
  Future<Map<String, dynamic>> createPlot(Map<String, dynamic> data) async {
    final res = await _dio.post('/plots/', data: data);
    return res.data;
  }

  Future<List<dynamic>> listPlots() async {
    final res = await _dio.get('/plots/');
    return res.data;
  }

  Future<Map<String, dynamic>> getPlot(String plotId) async {
    final res = await _dio.get('/plots/$plotId');
    return res.data;
  }

  Future<Map<String, dynamic>> uploadPhoto(
    String plotId,
    String filePath,
    String category, {
    double? lat,
    double? lng,
  }) async {
    final formData = FormData.fromMap({
      'file':     await MultipartFile.fromFile(filePath),
      'category': category,
      if (lat != null) 'gps_lat': lat.toString(),
      if (lng != null) 'gps_lng': lng.toString(),
    });
    final res = await _dio.post('/plots/$plotId/photos', data: formData);
    return res.data;
  }

  Future<Map<String, dynamic>> generateCertificate(String plotId) async {
    final res = await _dio.post('/plots/$plotId/generate-certificate');
    return res.data;
  }

  Future<Map<String, dynamic>> verifyCertificate(String lvPlotId) async {
    final res = await _dio.get('/plots/verify/$lvPlotId');
    return res.data;
  }
}

final api = ApiService();
