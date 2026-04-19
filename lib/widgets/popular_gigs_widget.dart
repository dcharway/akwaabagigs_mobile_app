import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utils/colors.dart';
import '../models/job.dart';
import '../providers/jobs_provider.dart';
import '../screens/job_details_screen.dart';

class PopularGigsWidget extends StatelessWidget {
  final VoidCallback? onSeeAllTap;

  const PopularGigsWidget({super.key, this.onSeeAllTap});

  @override
  Widget build(BuildContext context) {
    final jobsProvider = context.watch<JobsProvider>();
    final gigs = jobsProvider.allJobs
        .where((j) => j.status == 'active')
        .take(3)
        .toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Popular Gigs',
                  style: TextStyle(
                    fontSize: 18,
                    color: AppColors.gray800,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextButton(
                  onPressed: onSeeAllTap,
                  child: const Text(
                    'See All',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.amber600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (jobsProvider.isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: CircularProgressIndicator(
                  color: AppColors.amber600,
                ),
              ),
            )
          else if (gigs.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.work_off_outlined,
                      size: 48,
                      color: AppColors.gray400,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'No gigs available yet',
                      style: TextStyle(
                        color: AppColors.gray500,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Column(
              children: gigs.map((gig) => _buildGigCard(context, gig)).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildGigCard(BuildContext context, Job gig) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => JobDetailsScreen(job: gig),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.gray200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Image or icon
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: gig.gigImages.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: gig.gigImages.first,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => const ColoredBox(
                        color: AppColors.amber50,
                        child: SizedBox(
                          width: 80,
                          height: 80,
                          child: Icon(
                            Icons.work_outline,
                            color: AppColors.amber600,
                          ),
                        ),
                      ),
                      errorWidget: (_, __, ___) => const ColoredBox(
                        color: AppColors.amber50,
                        child: SizedBox(
                          width: 80,
                          height: 80,
                          child: Icon(
                            Icons.work_outline,
                            color: AppColors.amber600,
                          ),
                        ),
                      ),
                    )
                  : Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.amber50, AppColors.amber400],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.work_outline,
                        color: AppColors.amber700,
                        size: 32,
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              gig.title,
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.gray900,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              gig.company,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.gray500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (gig.category != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.amber400.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            gig.category!,
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.amber700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 14,
                            color: AppColors.gray500,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            gig.location,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.gray600,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        gig.salary,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.amber700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
