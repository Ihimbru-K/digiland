import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/theme.dart';
import '../../core/api_service.dart';
import '../plot/new_plot_screen.dart';
import '../plot/plot_detail_screen.dart';
import '../verify/verify_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<dynamic> _plots = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPlots();
  }

  Future<void> _loadPlots() async {
    setState(() { _loading = true; });
    try {
      final plots = await api.listPlots();
      setState(() { _plots = plots; });
    } catch (e) {
      // handle error
    } finally {
      setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          const Icon(Icons.terrain, size: 22),
          const SizedBox(width: 8),
          const Text('LandVault'),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'Verify Certificate',
            onPressed: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const VerifyScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadPlots,
        child: CustomScrollView(
          slivers: [
            // Stats banner
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryMid],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome, ${user?.displayName ?? 'Agent'}',
                      style: const TextStyle(
                        color: Colors.white, fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_plots.length} plot${_plots.length == 1 ? '' : 's'} registered',
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    Row(children: [
                      _StatChip(
                        label: 'Complete',
                        count: _plots.where((p) => p['status'] == 'complete').length,
                        color: AppColors.accent,
                      ),
                      const SizedBox(width: 12),
                      _StatChip(
                        label: 'Draft',
                        count: _plots.where((p) => p['status'] == 'draft').length,
                        color: Colors.white54,
                      ),
                    ]),
                  ],
                ),
              ),
            ),

            // Plot list header
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverToBoxAdapter(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Registered Plots',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    TextButton.icon(
                      onPressed: _loadPlots,
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Refresh'),
                    ),
                  ],
                ),
              ),
            ),

            // List
            _loading
              ? const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()))
              : _plots.isEmpty
                ? SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.map_outlined, size: 64,
                            color: AppColors.textGray.withOpacity(0.5)),
                          const SizedBox(height: 16),
                          Text('No plots registered yet',
                            style: Theme.of(context).textTheme.bodyMedium),
                          const SizedBox(height: 8),
                          Text('Tap + to register your first plot',
                            style: Theme.of(context).textTheme.bodyMedium),
                        ],
                      ),
                    ),
                  )
                : SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) => _PlotCard(
                          plot: _plots[i],
                          onTap: () => Navigator.push(context,
                            MaterialPageRoute(
                              builder: (_) => PlotDetailScreen(plotId: _plots[i]['id']),
                            ),
                          ).then((_) => _loadPlots()),
                        ),
                        childCount: _plots.length,
                      ),
                    ),
                  ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const NewPlotScreen()),
        ).then((_) => _loadPlots()),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_location_alt),
        label: const Text('Register Plot'),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _StatChip({required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text('$count $label',
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _PlotCard extends StatelessWidget {
  final Map<String, dynamic> plot;
  final VoidCallback onTap;
  const _PlotCard({required this.plot, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isComplete = plot['status'] == 'complete';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: isComplete
                  ? AppColors.primaryLight
                  : AppColors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isComplete ? Icons.verified : Icons.pending_outlined,
                color: isComplete ? AppColors.primary : AppColors.warning,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(plot['owner_name'] ?? '',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(plot['lv_plot_id'] ?? '',
                    style: TextStyle(
                      color: AppColors.primaryMid,
                      fontSize: 13, fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${plot['acquisition_method'] ?? ''} • ${plot['region'] ?? 'Bamenda'}',
                    style: const TextStyle(color: AppColors.textGray, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textGray),
          ]),
        ),
      ),
    );
  }
}
