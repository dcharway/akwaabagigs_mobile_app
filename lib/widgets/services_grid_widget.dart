import 'package:flutter/material.dart';
import '../utils/colors.dart';

class ServicesGridWidget extends StatelessWidget {
  final VoidCallback? onGigsTap;
  final VoidCallback? onStoreTap;

  const ServicesGridWidget({
    super.key,
    this.onGigsTap,
    this.onStoreTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              'Our Services',
              style: TextStyle(
                fontSize: 18,
                color: AppColors.gray800,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: _buildServiceCard(
                  name: 'Akwaaba Gigs',
                  icon: Icons.business_center,
                  gradientColors: const [AppColors.amber500, AppColors.amber700],
                  color: AppColors.amber600,
                  onTap: onGigsTap,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildServiceCard(
                  name: 'Akwaaba Store',
                  icon: Icons.shopping_bag,
                  gradientColors: const [AppColors.red500, AppColors.red700],
                  color: AppColors.red600,
                  onTap: onStoreTap,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildServiceCard({
    required String name,
    required IconData icon,
    required List<Color> gradientColors,
    required Color color,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AspectRatio(
        aspectRatio: 1.0,
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.amber50, Colors.white],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.amber400.withOpacity(0.2),
              width: 1.5,
            ),
          ),
          child: Stack(
            children: [
              // Adinkra-inspired decorative corners
              _buildCorner(top: 4, left: 4, borderTop: true, borderLeft: true),
              _buildCorner(top: 4, right: 4, borderTop: true, borderRight: true),
              _buildCorner(bottom: 4, left: 4, borderBottom: true, borderLeft: true),
              _buildCorner(bottom: 4, right: 4, borderBottom: true, borderRight: true),
              // Content
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: gradientColors,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: color.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        icon,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.gray800,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCorner({
    double? top,
    double? bottom,
    double? left,
    double? right,
    bool borderTop = false,
    bool borderBottom = false,
    bool borderLeft = false,
    bool borderRight = false,
  }) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          border: Border(
            top: borderTop
                ? const BorderSide(color: AppColors.amber400, width: 2)
                : BorderSide.none,
            bottom: borderBottom
                ? const BorderSide(color: AppColors.amber400, width: 2)
                : BorderSide.none,
            left: borderLeft
                ? const BorderSide(color: AppColors.amber400, width: 2)
                : BorderSide.none,
            right: borderRight
                ? const BorderSide(color: AppColors.amber400, width: 2)
                : BorderSide.none,
          ),
        ),
      ),
    );
  }
}
