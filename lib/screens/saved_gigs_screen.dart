import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/job.dart';
import '../providers/jobs_provider.dart';
import '../services/api_service.dart';
import '../widgets/job_card.dart';
import 'job_details_screen.dart';

class SavedGigsScreen extends StatefulWidget {
  const SavedGigsScreen({super.key});

  @override
  State<SavedGigsScreen> createState() => _SavedGigsScreenState();
}

class _SavedGigsScreenState extends State<SavedGigsScreen> {
  List<String> _savedIds = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSavedIds();
  }

  Future<void> _loadSavedIds() async {
    setState(() => _isLoading = true);
    _savedIds = await ApiService.getSavedJobIds();
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final jobsProvider = context.watch<JobsProvider>();
    final savedJobs = jobsProvider.allJobs
        .where((j) => _savedIds.contains(j.id))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Gigs'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : savedJobs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.bookmark_border,
                          size: 64,
                          color: Theme.of(context).colorScheme.outline),
                      const SizedBox(height: 16),
                      Text('No saved gigs',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text(
                        'Bookmark gigs from the details page to save them here',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadSavedIds,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: savedJobs.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: JobCard(
                          job: savedJobs[index],
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => JobDetailsScreen(
                                    job: savedJobs[index]),
                              ),
                            ).then((_) => _loadSavedIds());
                          },
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
