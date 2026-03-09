import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../core/theme.dart';
import '../../core/api_service.dart';

class NewPlotScreen extends StatefulWidget {
  const NewPlotScreen({super.key});
  @override
  State<NewPlotScreen> createState() => _NewPlotScreenState();
}

class _NewPlotScreenState extends State<NewPlotScreen> {
  int _step = 0;
  bool _loading = false;
  String? _plotId;      // internal UUID from backend
  String? _lvPlotId;    // human-readable LV-2026-XXXX

  // Step 1 — Owner info
  final _ownerName    = TextEditingController();
  final _ownerId      = TextEditingController();
  final _ownerPhone   = TextEditingController();
  final _description  = TextEditingController();
  String _acquisition = 'purchase';

  // Step 2 — GPS points
  List<Map<String, dynamic>> _gpsPoints = [];

  // Step 3 — Photos
  List<File> _photos   = [];
  List<String> _photoIds = [];

  // Step 4 — Witnesses
  final List<Map<String, TextEditingController>> _witnesses = [
    {
      'name':         TextEditingController(),
      'phone':        TextEditingController(),
      'relationship': TextEditingController(),
      'statement':    TextEditingController(),
    },
    {
      'name':         TextEditingController(),
      'phone':        TextEditingController(),
      'relationship': TextEditingController(),
      'statement':    TextEditingController(),
    },
  ];

  // ── GPS ───────────────────────────────────────────────────
  Future<void> _captureGPS() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showSnack('Location services disabled');
      return;
    }
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied) {
        _showSnack('Location permission denied');
        return;
      }
    }

    setState(() { _loading = true; });
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _gpsPoints.add({
          'latitude':       pos.latitude,
          'longitude':      pos.longitude,
          'altitude':       pos.altitude,
          'accuracy':       pos.accuracy,
          'sequence_order': _gpsPoints.length,
        });
      });
      _showSnack('GPS point captured: ${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}');
    } catch (e) {
      _showSnack('GPS error: $e');
    } finally {
      setState(() { _loading = false; });
    }
  }

  // ── Photo ─────────────────────────────────────────────────
  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final xfile  = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
      maxWidth: 1920,
    );
    if (xfile != null) {
      setState(() { _photos.add(File(xfile.path)); });
    }
  }

  Future<void> _uploadPhotos() async {
    if (_plotId == null) return;
    setState(() { _loading = true; });
    try {
      for (final photo in _photos) {
        final result = await api.uploadPhoto(
          _plotId!, photo.path, 'overview',
        );
        _photoIds.add(result['photo_id']);
      }
    } catch (e) {
      _showSnack('Photo upload failed: $e');
    } finally {
      setState(() { _loading = false; });
    }
  }

  // ── Submit Steps ──────────────────────────────────────────
  Future<void> _submitOwnerAndGPS() async {
    if (_ownerName.text.trim().isEmpty) {
      _showSnack('Owner name is required');
      return;
    }
    if (_gpsPoints.isEmpty) {
      _showSnack('Capture at least 1 GPS point');
      return;
    }
    setState(() { _loading = true; });
    try {
      final witnesses = _witnesses.map((w) => {
        'full_name':           w['name']!.text.trim(),
        'phone':               w['phone']!.text.trim(),
        'relationship_to_plot': w['relationship']!.text.trim(),
        'statement_text':      w['statement']!.text.trim(),
      }).where((w) => w['full_name']!.toString().isNotEmpty).toList();

      final result = await api.createPlot({
        'owner_name':         _ownerName.text.trim(),
        'owner_id_number':    _ownerId.text.trim().isEmpty ? null : _ownerId.text.trim(),
        'owner_phone':        _ownerPhone.text.trim().isEmpty ? null : _ownerPhone.text.trim(),
        'acquisition_method': _acquisition,
        'description':        _description.text.trim(),
        'gps_points':         _gpsPoints,
        'witnesses':          witnesses,
      });
      setState(() {
        _plotId   = result['plot_id'];
        _lvPlotId = result['lv_plot_id'];
      });
      _showSnack('Plot created: $_lvPlotId');
      setState(() { _step = 2; });
    } catch (e) {
      _showSnack('Error: $e');
    } finally {
      setState(() { _loading = false; });
    }
  }

  Future<void> _generateCertificate() async {
    if (_plotId == null) return;
    setState(() { _loading = true; });
    try {
      await _uploadPhotos();
      final result = await api.generateCertificate(_plotId!);
      if (mounted) {
        Navigator.pop(context);
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: Row(children: [
              Icon(Icons.verified, color: AppColors.primary),
              const SizedBox(width: 8),
              const Text('Certificate Generated!'),
            ]),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Plot ID: ${result['lv_plot_id']}',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text('Tx Hash: ${result['tx_hash'].toString().substring(0, 20)}...',
                  style: const TextStyle(fontSize: 12, color: AppColors.textGray)),
                const SizedBox(height: 8),
                Text('Certificate is anchored on Polygon blockchain.',
                  style: const TextStyle(fontSize: 13)),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      _showSnack('Certificate generation failed: $e');
    } finally {
      setState(() { _loading = false; });
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  // ── UI ────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Register Plot — Step ${_step + 1}/3'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: (_step + 1) / 3,
            backgroundColor: Colors.white24,
            color: AppColors.accent,
          ),
        ),
      ),
      body: [_buildStep1, _buildStep2, _buildStep3][_step](),
    );
  }

  Widget _buildStep1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(icon: Icons.person, title: 'Owner Information'),
          const SizedBox(height: 16),
          TextField(controller: _ownerName,
            decoration: const InputDecoration(labelText: 'Full Name *')),
          const SizedBox(height: 12),
          TextField(controller: _ownerId,
            decoration: const InputDecoration(labelText: 'National ID (optional)')),
          const SizedBox(height: 12),
          TextField(controller: _ownerPhone, keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Phone Number')),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _acquisition,
            decoration: const InputDecoration(labelText: 'Acquisition Method'),
            items: ['purchase', 'inheritance', 'customary', 'gift']
              .map((m) => DropdownMenuItem(value: m,
                child: Text(m[0].toUpperCase() + m.substring(1))))
              .toList(),
            onChanged: (v) => setState(() { _acquisition = v!; }),
          ),
          const SizedBox(height: 12),
          TextField(controller: _description, maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Plot Description',
              hintText: 'e.g. Residential plot near main road...',
            )),

          const SizedBox(height: 24),
          _SectionHeader(icon: Icons.gps_fixed, title: 'GPS Boundary Points'),
          const SizedBox(height: 12),

          ..._gpsPoints.asMap().entries.map((e) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(children: [
              Icon(Icons.location_pin, color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              Text('P${e.key + 1}: ${e.value['latitude'].toStringAsFixed(5)}, '
                '${e.value['longitude'].toStringAsFixed(5)}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() => _gpsPoints.removeAt(e.key)),
                child: Icon(Icons.close, size: 16, color: AppColors.textGray),
              ),
            ]),
          )),

          OutlinedButton.icon(
            onPressed: _loading ? null : _captureGPS,
            icon: _loading
              ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.my_location),
            label: Text(_gpsPoints.isEmpty ? 'Capture GPS Point' : 'Add Another Point'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
            ),
          ),

          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loading ? null : () => setState(() => _step = 1),
              child: const Text('Next: Add Witnesses'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep2() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(icon: Icons.people, title: 'Witness Statements'),
          const SizedBox(height: 4),
          Text('Minimum 2 witnesses required — neighbors who can confirm the plot.',
            style: const TextStyle(color: AppColors.textGray, fontSize: 13)),
          const SizedBox(height: 20),

          ..._witnesses.asMap().entries.map((e) => _WitnessCard(
            index: e.key,
            controllers: e.value,
          )),

          const SizedBox(height: 24),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _step = 0),
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.textGray),
                child: const Text('Back'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _loading ? null : _submitOwnerAndGPS,
                child: _loading
                  ? const SizedBox(height: 20, width: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Save & Add Photos'),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildStep3() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(children: [
              Icon(Icons.check_circle, color: AppColors.primary),
              const SizedBox(width: 8),
              Text('Plot $_lvPlotId saved',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ]),
          ),
          const SizedBox(height: 24),

          _SectionHeader(icon: Icons.photo_camera, title: 'Plot Photos'),
          const SizedBox(height: 4),
          Text('Take photos of the plot from all sides. Min 2 photos recommended.',
            style: const TextStyle(color: AppColors.textGray, fontSize: 13)),
          const SizedBox(height: 16),

          if (_photos.isNotEmpty) ...[
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _photos.length,
                itemBuilder: (ctx, i) => Stack(
                  children: [
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      width: 100, height: 100,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        image: DecorationImage(
                          image: FileImage(_photos[i]),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned(top: 4, right: 12,
                      child: GestureDetector(
                        onTap: () => setState(() => _photos.removeAt(i)),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.close, color: Colors.white, size: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          OutlinedButton.icon(
            onPressed: _pickPhoto,
            icon: const Icon(Icons.add_a_photo),
            label: const Text('Take Photo'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
            ),
          ),

          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 16),

          Text('Generate Certificate',
            style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'This will create a Property Verification Certificate PDF and anchor its hash on the Polygon blockchain.',
            style: const TextStyle(color: AppColors.textGray, fontSize: 13),
          ),
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _loading ? null : _generateCertificate,
              icon: _loading
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.verified),
              label: Text(_loading ? 'Anchoring to Blockchain...' : 'Generate Certificate'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryMid,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, color: AppColors.primary, size: 20),
      const SizedBox(width: 8),
      Text(title, style: Theme.of(context).textTheme.titleLarge),
    ]);
  }
}

class _WitnessCard extends StatelessWidget {
  final int index;
  final Map<String, TextEditingController> controllers;
  const _WitnessCard({required this.index, required this.controllers});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Witness ${index + 1}',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          TextField(controller: controllers['name'],
            decoration: const InputDecoration(labelText: 'Full Name *')),
          const SizedBox(height: 10),
          TextField(controller: controllers['phone'],
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Phone Number *')),
          const SizedBox(height: 10),
          TextField(controller: controllers['relationship'],
            decoration: const InputDecoration(
              labelText: 'Relationship to Plot',
              hintText: 'e.g. Neighbor, Quarter head...',
            )),
          const SizedBox(height: 10),
          TextField(controller: controllers['statement'],
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Statement *',
              hintText: 'Describe what you know about this plot...',
            )),
        ],
      ),
    );
  }
}
