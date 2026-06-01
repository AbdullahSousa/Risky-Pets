import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:risky_pets/api_service.dart';
import 'package:risky_pets/guest_id.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _noteController = TextEditingController();

  File? _imageFile;
  bool _isLoading = false;
  String _selectedInteraction = '';

  final List<String> _selectedWounds = [];
  final List<String> _selectedBehaviors = [];

  final List<String> interactions = ['BITE', 'SCRATCH', 'TOUCH'];
  final List<String> wounds = [
    'Broke the skin / drew blood',
    'Deep puncture wound',
    'Lesion is oozing pus / infected',
  ];
  final List<String> behaviors = ['Aggression', 'Drooling', 'Itching a lot'];

  final Color selectedColor = Colors.green.shade300;
  final Color borderColor = Colors.grey.shade400;

  // ── Image Picker ─────────────────────────────────────────────────────────────

  Future<void> _takePhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (photo != null) {
        setState(() {
          _imageFile = File(photo.path);
          _noteController.clear();
        });
      }
    } catch (e) {
      _showError('Failed to take photo: $e');
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (image != null) {
        setState(() {
          _imageFile = File(image.path);
          _noteController.clear();
        });
      }
    } catch (e) {
      _showError('Failed to pick image: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  // ── Firebase helpers ──────────────────────────────────────────────────────────

  Future<String?> _uploadImage(File image) async {
    final user = FirebaseAuth.instance.currentUser;
    final fileName =
        '${user?.uid ?? 'anonymous'}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final ref = FirebaseStorage.instance.ref().child('scans/$fileName');
    await ref.putFile(image);
    return await ref.getDownloadURL();
  }

  Future<void> _logToFirestore({
    required AgentResult result,
    required String? imageUrl,
    required String note,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    final userId = user?.uid ?? await GuestId.get();

    await FirebaseFirestore.instance.collection('scans').add({
      // ── Identity & meta ──────────────────────────────────────────────────
      'userId':          userId,
      'isGuest':         user == null,
      'timestamp':       FieldValue.serverTimestamp(),
      'imageUrl':        imageUrl,
      'note':            note,
      // ── User inputs (shown in history detail) ────────────────────────────
      'interactionType': _selectedInteraction.toLowerCase(),
      'brokeSkin':       _selectedWounds.contains('Broke the skin / drew blood'),
      'deepPuncture':    _selectedWounds.contains('Deep puncture wound'),
      'lesionOozing':    _selectedWounds.contains('Lesion is oozing pus / infected'),
      'rabiesSigns':     _selectedBehaviors.contains('Aggression') ||
                         _selectedBehaviors.contains('Drooling'),
      // ── Gemini agent fields (keys match history.dart exactly) ────────────
      ...result.toMap(),
    });
  }

  // ── Result dialog ─────────────────────────────────────────────────────────────

  void _showResultDialog(AgentResult result) {
    final Color riskColor = switch (result.riskLevel.toUpperCase()) {
      'LOW'      => Colors.green,
      'MODERATE' => Colors.orange,
      'HIGH'     => Colors.deepOrange,
      _          => Colors.red,
    };

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.smart_toy_outlined, color: riskColor),
            const SizedBox(width: 8),
            const Text('AI Risk Assessment'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [

              // ── Risk level badge ──────────────────────────────────────────
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  decoration: BoxDecoration(
                    color: riskColor,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(
                    result.riskLevel.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Divider(),

              // ── Animal & bite risk ────────────────────────────────────────
              _resultRow(Icons.pets, 'Animal', result.animalType),
              _resultRow(
                Icons.warning_amber,
                'Bite Risk',
                result.biteRiskLevel,
                valueColor: switch (result.biteRiskLevel.toLowerCase()) {
                  'high'   => Colors.red,
                  'medium' => Colors.orange,
                  _        => Colors.green,
                },
              ),
              const Divider(),

              // ── Health flags ──────────────────────────────────────────────
              if (result.healthFlags.isNotEmpty) ...[
                const Text(
                  'Health Flags',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 6),
                ...result.healthFlags.map((f) => _healthFlagRow(f)),
                const SizedBox(height: 8),
                const Divider(),
              ],

              // ── Agent assessment text ─────────────────────────────────────
              if (result.answer.isNotEmpty) ...[
                const Text(
                  'Assessment',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 6),
                Text(result.answer, style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 12),
              ],

              // ── Advice box ────────────────────────────────────────────────
              if (result.advice.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: riskColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: riskColor.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.medical_services, color: riskColor, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          result.advice,
                          style: TextStyle(
                            color: riskColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // ── Row helpers ───────────────────────────────────────────────────────────────

  Widget _resultRow(IconData icon, String label, String value,
      {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w500)),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: valueColor),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _healthFlagRow(HealthFlag flag) {
    final Color sc = switch (flag.severity.toLowerCase()) {
      'high'   => Colors.red,
      'medium' => Colors.orange,
      _        => Colors.green,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(Icons.circle, size: 8, color: sc),
          const SizedBox(width: 8),
          Expanded(
            child: Text(flag.issue, style: const TextStyle(fontSize: 13)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: sc.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              flag.severity,
              style: TextStyle(
                fontSize: 11,
                color: sc,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Submit ────────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (_imageFile == null) {
      _showError('Please select or take a photo first.');
      return;
    }
    if (_selectedInteraction.isEmpty) {
      _showError('Please select an interaction type.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // ── 1. Call Gemini agent ──────────────────────────────────────────────
      final result = await ApiService.consultAgent(
        image: _imageFile!,
        interactionType: _selectedInteraction.toLowerCase(),
        brokeSkin:    _selectedWounds.contains('Broke the skin / drew blood'),
        deepPuncture: _selectedWounds.contains('Deep puncture wound'),
        lesionOozing: _selectedWounds.contains('Lesion is oozing pus / infected'),
        rabiesSigns:  _selectedBehaviors.contains('Aggression') ||
                      _selectedBehaviors.contains('Drooling'),
        note: _noteController.text.trim(),
      );

      // ── 2. Upload image (non-fatal) ───────────────────────────────────────
      String? imageUrl;
      try {
        imageUrl = await _uploadImage(_imageFile!);
      } catch (e) {
        debugPrint('Image upload failed: $e');
      }

      // ── 3. Save to Firestore (non-fatal) ──────────────────────────────────
      try {
        await _logToFirestore(
          result: result,
          imageUrl: imageUrl,
          note: _noteController.text.trim(),
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Result saved locally but failed to sync to history.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }

      // ── 4. Show result dialog & reset form ─────────────────────────────────
      if (mounted) {
        _showResultDialog(result);
        setState(() {
          _imageFile = null;
          _selectedInteraction = '';
          _selectedWounds.clear();
          _selectedBehaviors.clear();
        });
        _noteController.clear();
      }
    } catch (e) {
      _showError('Failed to assess: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Chip builder ──────────────────────────────────────────────────────────────

  Widget _chip(String item, bool isSelected, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final unselectedBg = isDark ? Colors.grey.shade800 : Colors.white;
    final chipTextColor = isDark ? Colors.white : Colors.black87;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? selectedColor : unselectedBg,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: isSelected ? selectedColor : borderColor,
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.grey.withValues(alpha: 0.3),
                    spreadRadius: 1,
                    blurRadius: 3,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Text(
          item,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? Colors.white : chipTextColor,
          ),
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [

          // Image preview
          Card(
            elevation: 4,
            child: Container(
              height: 300,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: _imageFile != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(_imageFile!, fit: BoxFit.cover),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_photo_alternate,
                            size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'No image selected',
                          style: TextStyle(
                              color: Colors.grey[600], fontSize: 16),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 16),

          // Camera / Gallery buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _takePhoto,
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Camera'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    foregroundColor: Colors.green.shade300,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _pickFromGallery,
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Gallery'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    foregroundColor: Colors.green.shade300,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Interaction type
          const Padding(
            padding: EdgeInsets.only(bottom: 12.0),
            child: Text(
              'Interaction Type',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          Wrap(
            spacing: 12.0,
            runSpacing: 12.0,
            children: interactions
                .map((item) => _chip(item, _selectedInteraction == item, () {
                      setState(() => _selectedInteraction = item);
                    }))
                .toList(),
          ),

          const SizedBox(height: 32),

          // Wound characteristics
          const Padding(
            padding: EdgeInsets.only(bottom: 12.0),
            child: Text(
              'Wound Characteristics',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          Wrap(
            spacing: 12.0,
            runSpacing: 12.0,
            children: wounds
                .map((item) => _chip(
                      item,
                      _selectedWounds.contains(item),
                      () => setState(() => _selectedWounds.contains(item)
                          ? _selectedWounds.remove(item)
                          : _selectedWounds.add(item)),
                    ))
                .toList(),
          ),

          const SizedBox(height: 32),

          // Behavioral signs
          const Padding(
            padding: EdgeInsets.only(bottom: 12.0),
            child: Text(
              'Behavioral Signs',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          Wrap(
            spacing: 12.0,
            runSpacing: 12.0,
            children: behaviors
                .map((item) => _chip(
                      item,
                      _selectedBehaviors.contains(item),
                      () => setState(() => _selectedBehaviors.contains(item)
                          ? _selectedBehaviors.remove(item)
                          : _selectedBehaviors.add(item)),
                    ))
                .toList(),
          ),

          const SizedBox(height: 32),

          // Note field
          TextField(
            controller: _noteController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Description',
              hintText: 'Add note (optional)',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8)),
              prefixIcon: const Icon(Icons.note),
            ),
          ),

          const SizedBox(height: 24),

          // Submit button
          ElevatedButton.icon(
            onPressed: _isLoading ? null : _submit,
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.send),
            label: Text(_isLoading ? 'Analyzing...' : 'Get AI Advice'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }
}