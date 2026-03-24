import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/colors.dart';
import '../providers/jobs_provider.dart';

class QuickStatsWidget extends StatelessWidget {
  const QuickStatsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final jobsProvider = context.watch<JobsProvider>();
    final jobCount = jobsProvider.allJobs.length;

    final stats = [
      _StatData(
        icon: Icons.people_outline,
        label: 'Active Users',
        value: '50K+',
        gradientColors: const [AppColors.blue500, AppColors.blue600],
      ),
      _StatData(
        icon: Icons.work_outline,
        label: 'Total Gigs',
        value: jobCount > 0 ? '${jobCount}+' : '0',
        gradientColors: const [AppColors.purple500, AppColors.purple600],
      ),
      _StatData(
        icon: Icons.star_outline,
        label: 'Avg Rating',
        value: '4.8',
        gradientColors: const [AppColors.amber500, AppColors.amber600],
      ),
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              'Our Impact',
              style: TextStyle(
                fontSize: 18,
                color: AppColors.gray800,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Row(
            children: stats.asMap().entries.map((entry) {
              final stat = entry.value;
              final isLast = entry.key == stats.length - 1;
              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: isLast ? 0 : 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.amber50, Colors.white],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.amber400.withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: stat.gradientColors,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          stat.icon,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        stat.value,
                        style: const TextStyle(
                          fontSize: 18,
                          color: AppColors.gray900,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        stat.label,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.gray600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _StatData {
  final IconData icon;
  final String label;
  final String value;
  final List<Color> gradientColors;

  _StatData({
    required this.icon,
    required this.label,
    required this.value,
    required this.gradientColors,
  });
}
