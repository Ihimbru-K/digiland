import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/theme.dart';
import '../../core/api_service.dart';

class VerifyScreen extends StatefulWidget {
  const VerifyScreen({super.key});
  @override
  State<VerifyScreen> createState() => _VerifyScreenState();
}

class _VerifyScreenState extends State<VerifyScreen> {
  bool _scanning = true;
  bool _loading  = false;
  Map<String, dynamic>? _result;
  String? _error;
  final _manualCtrl = TextEditingController();

  Future<void> _verify(String lvPlotId) async {
    setState(() { _loading = true; _scanning = false; _error = null; _result = null; });
    try {
      final data = await api.verifyCertificate(lvPlotId);
      setState(() { _result = data; });
    } catch (e) {
      setState(() { _error = 'Certificate not found or invalid: $lvPlotId'; });
    } finally {
      setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify Certificate')),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _result != null
          ? _buildResult()
          : _scanning
            ? _buildScanner()
            : _buildManual(),
    );
  }

  Widget _buildScanner() {
    return Column(
      children: [
        Expanded(
          child: MobileScanner(
            onDetect: (capture) {
              final barcode = capture.barcodes.first;
              final raw = barcode.rawValue ?? '';
              // Extract LV-YYYY-NNNN from URL or direct
              final match = RegExp(r'LV-\d{4}-\d{4}').firstMatch(raw);
              if (match != null) {
                _verify(match.group(0)!);
              }
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Text('Scan the QR code on a LandVault certificate',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textGray),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => setState(() { _scanning = false; }),
                child: const Text('Enter Plot ID manually'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildManual() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Enter Plot ID', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text('Format: LV-2026-0001', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 24),
          TextField(
            controller: _manualCtrl,
            decoration: const InputDecoration(
              labelText: 'Plot ID',
              hintText: 'LV-2026-0001',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: AppColors.error, fontSize: 13)),
          ],
          const SizedBox(height: 20),
          Row(children: [
            OutlinedButton(
              onPressed: () => setState(() { _scanning = true; }),
              child: const Text('Scan QR'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  if (_manualCtrl.text.trim().isNotEmpty) {
                    _verify(_manualCtrl.text.trim().toUpperCase());
                  }
                },
                child: const Text('Verify'),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildResult() {
    final bc = _result!['blockchain'] as Map<String, dynamic>?;
    final verified = bc?['verified'] == true;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: verified ? AppColors.primaryLight : AppColors.error.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: verified ? AppColors.accent : AppColors.error.withOpacity(0.3),
              ),
            ),
            child: Column(
              children: [
                Icon(
                  verified ? Icons.verified : Icons.cancel,
                  size: 56,
                  color: verified ? AppColors.primary : AppColors.error,
                ),
                const SizedBox(height: 8),
                Text(
                  verified ? 'Certificate Verified ✓' : 'Not Found',
                  style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w700,
                    color: verified ? AppColors.primary : AppColors.error,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  verified
                    ? 'This record exists on the Polygon blockchain'
                    : 'No blockchain record found for this plot ID',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: verified ? AppColors.primaryMid : AppColors.error,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (verified) ...[
            _DetailRow('Plot ID',    _result!['lv_plot_id']),
            _DetailRow('Owner',      _result!['owner_name']),
            _DetailRow('Region',     _result!['region'] ?? 'N/A'),
            _DetailRow('Network',    bc!['network']),
            _DetailRow('Registered', DateTime.fromMillisecondsSinceEpoch(
              (bc['timestamp'] as int) * 1000).toString().split('.')[0]),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  setState(() { _result = null; _scanning = true; });
                },
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Scan Another'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String? value;
  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(children: [
        Text(label,
          style: const TextStyle(color: AppColors.textGray, fontSize: 13, fontWeight: FontWeight.w500)),
        const Spacer(),
        Text(value ?? 'N/A',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      ]),
    );
  }
}
