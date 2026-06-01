// api_service.dart
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'dart:convert';
import 'package:path/path.dart' as p;

class ApiService {
  static const String _baseUrl =
      'https://zoonotic-risk-api-823512595658.europe-west3.run.app';

  static Future<AgentResult> consultAgent({
    required File image,
    required String interactionType,
    required bool brokeSkin,
    required bool deepPuncture,
    required bool lesionOozing,
    required bool rabiesSigns,
    String? note,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/consult-agent/');
    final request = http.MultipartRequest('POST', uri);

    final ext = p.extension(image.path).toLowerCase().replaceFirst('.', '');
    request.files.add(await http.MultipartFile.fromPath(
      'file', image.path,
      contentType: MediaType('image', _mimeFromExt(ext)),
    ));

    request.fields['interaction_type'] = interactionType;
    request.fields['broke_skin']       = brokeSkin.toString();
    request.fields['deep_puncture']    = deepPuncture.toString();
    request.fields['lesion_oozing']    = lesionOozing.toString();
    request.fields['rabies_signs']     = rabiesSigns.toString();
    if (note != null && note.isNotEmpty) request.fields['note'] = note;

    final streamed = await request.send().timeout(
      const Duration(seconds: 90),
      onTimeout: () => throw Exception('Request timed out. Please try again.'),
    );
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode == 200) {
      return AgentResult.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Error ${response.statusCode}: ${response.body}');
    }
  }

  static String _mimeFromExt(String ext) => const {
    'jpg': 'jpeg', 'jpeg': 'jpeg', 'png': 'png',
    'webp': 'webp', 'bmp': 'bmp', 'gif': 'gif',
    'heic': 'heic', 'heif': 'heif',
  }[ext] ?? 'jpeg';
}

class HealthFlag {
  final String issue;
  final String severity;
  HealthFlag({required this.issue, required this.severity});

  factory HealthFlag.fromJson(Map<String, dynamic> j) =>
      HealthFlag(issue: j['issue'] ?? '', severity: j['severity'] ?? '');

  Map<String, dynamic> toMap() => {'issue': issue, 'severity': severity};
}

class AgentResult {
  final String animalType;
  final String riskLevel;     
  final String biteRiskLevel; 
  final List<HealthFlag> healthFlags;
  final String answer;
  final String advice;

  AgentResult({
    required this.animalType,
    required this.riskLevel,
    required this.biteRiskLevel,
    required this.healthFlags,
    required this.answer,
    required this.advice,
  });

  factory AgentResult.fromJson(Map<String, dynamic> j) => AgentResult(
    animalType:    j['animal_type']     ?? '',
    riskLevel:     j['risk_level']      ?? 'UNKNOWN',
    biteRiskLevel: j['bite_risk_level'] ?? '',
    healthFlags:   (j['health_flags'] as List<dynamic>? ?? [])
        .map((e) => HealthFlag.fromJson(e as Map<String, dynamic>))
        .toList(),
    answer:  j['answer']  ?? '',
    advice:  j['advice']  ?? '',
  );

  Map<String, dynamic> toMap() => {
    'riskLevel':       riskLevel,     
    'detectedSpecies': animalType,    
    'userAction':      advice,        
    'biteRiskLevel':   biteRiskLevel, 
    'answer':          answer,        
    'healthFlags':     healthFlags.map((f) => f.toMap()).toList(),
  };
}