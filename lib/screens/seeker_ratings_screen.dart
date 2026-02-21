import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/rating.dart';
import '../services/api_service.dart';

class SeekerRatingsScreen extends StatefulWidget {
  final String email;
  final String name;

  const SeekerRatingsScreen({
    super.key,
    required this.email,
    required this.name,
  });

  @override
  State<SeekerRatingsScreen> createState() => _SeekerRatingsScreenState();
}

class _SeekerRatingsScreenState extends State<SeekerRatingsScreen> {
  SeekerRatingSummary? _summary;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRatings();
  }

  Future<void> _loadRatings() async {
    setState(() => _isLoading = true);

    _summary = await ApiService.getSeekerRatings(widget.email);

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.name}\'s Ratings'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _summary == null || _summary!.totalRatings == 0
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.star_border,
                          size: 64,
                          color: Theme.of(context).colorScheme.outline),
                      const SizedBox(height: 16),
                      Text('No ratings yet',
                          style: Theme.of(context).textTheme.titleMedium),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadRatings,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        // Summary card
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              children: [
                                Text(
                                  _summary!.averageRating.toStringAsFixed(1),
                                  style: Theme.of(context)
                                      .textTheme
                                      .displayMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.amber.shade800,
                                      ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: List.generate(5, (i) {
                                    return Icon(
                                      i < _summary!.averageRating.round()
                                          ? Icons.star
                                          : Icons.star_border,
                                      color: Colors.amber,
                                      size: 28,
                                    );
                                  }),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${_summary!.totalRatings} rating${_summary!.totalRatings == 1 ? '' : 's'}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .outline,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Individual ratings
                        ...(_summary!.ratings.map(
                          (rating) => _buildRatingCard(rating),
                        )),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildRatingCard(Rating rating) {
    final dateFormat = DateFormat('MMM d, yyyy');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ...List.generate(5, (i) {
                  return Icon(
                    i < rating.rating ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    size: 18,
                  );
                }),
                const Spacer(),
                Text(
                  dateFormat.format(rating.createdAt),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'by ${rating.posterName}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            if (rating.review != null && rating.review!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                rating.review!,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
