import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme.dart';
import '../../core/api_service.dart';

class PlotDetailScreen extends StatefulWidget {
  final String plotId;
  const PlotDetailScreen({super.key, required this.plotId});
  @override
  State<PlotDetailScreen> createState() => _PlotDetailScreenState();
}

class _PlotDetailScreenState extends State<PlotDetailScreen> {
  Map<String, dynamic>? _plot;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await api.getPlot(widget.plotId);
      setState(() { _plot = data; });
    } catch (e) {
      // handle
    } finally {
      setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_plot == null) return const Scaffold(body: Center(child: Text('Plot not found')));

    final cert = _plot!['certificate'];
    return Scaffold(
      appBar: AppBar(
        title: Text(_plot!['lv_plot_id'] ?? 'Plot Detail'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _InfoCard(title: 'Owner', children: [
              _Row('Name',        _plot!['owner_name']),
              _Row('ID Number',   _plot!['owner_id_number'] ?? 'N/A'),
              _Row('Phone',       _plot!['owner_phone'] ?? 'N/A'),
              _Row('Acquisition', _plot!['acquisition_method']),
              _Row('Status',      _plot!['status'].toString().toUpperCase()),
            ]),
            const SizedBox(height: 12),

            _InfoCard(title: 'GPS Points (${(_plot!['gps_points'] as List).length})', children: [
              ...(_plot!['gps_points'] as List).asMap().entries.map((e) =>
                _Row('P${e.key + 1}',
                  '${e.value['lat'].toStringAsFixed(5)}, ${e.value['lng'].toStringAsFixed(5)}'),
              ),
            ]),
            const SizedBox(height: 12),

            _InfoCard(title: 'Witnesses (${(_plot!['witnesses'] as List).length})', children: [
              ...(_plot!['witnesses'] as List).map((w) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(w['name'], style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text('"${w['statement']}"',
                      style: const TextStyle(fontSize: 13, color: AppColors.textGray,
                        fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              )),
            ]),
            const SizedBox(height: 12),

            if (cert != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryMid],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(children: [
                      Icon(Icons.verified, color: Colors.white),
                      SizedBox(width: 8),
                      Text('Certificate on Blockchain',
                        style: TextStyle(color: Colors.white,
                          fontWeight: FontWeight.w700, fontSize: 16)),
                    ]),
                    const SizedBox(height: 12),
                    Text('Tx: ${cert['tx_hash'].toString().substring(0, 20)}...',
                      style: const TextStyle(color: Colors.white70, fontSize: 12,
                        fontFamily: 'monospace')),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => launchUrl(Uri.parse(cert['pdf_url'])),
                          icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
                          label: const Text('View PDF', style: TextStyle(color: Colors.white)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white54),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => launchUrl(
                            Uri.parse('https://amoy.polygonscan.com/tx/${cert['tx_hash']}')),
                          icon: const Icon(Icons.link, color: Colors.white),
                          label: const Text('Explorer', style: TextStyle(color: Colors.white)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white54),
                          ),
                        ),
                      ),
                    ]),
                  ],
                ),
              ),
            ] else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.warning.withOpacity(0.3)),
                ),
                child: Row(children: [
                  Icon(Icons.pending, color: AppColors.warning),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('No certificate yet. Complete all fields and generate.',
                      style: TextStyle(fontSize: 14)),
                  ),
                ]),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _InfoCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          )),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String? value;
  const _Row(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
              style: const TextStyle(color: AppColors.textGray, fontSize: 13)),
          ),
          Expanded(
            child: Text(value ?? 'N/A',
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
