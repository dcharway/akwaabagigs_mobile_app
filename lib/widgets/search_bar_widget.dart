import 'package:flutter/material.dart';
import '../utils/colors.dart';

class SearchBarWidget extends StatelessWidget {
  final VoidCallback? onTap;
  final ValueChanged<String>? onChanged;
  final TextEditingController? controller;
  final String locationText;

  const SearchBarWidget({
    super.key,
    this.onTap,
    this.onChanged,
    this.controller,
    this.locationText = 'Accra, Ghana',
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        children: [
          // Search Input
          GestureDetector(
            onTap: onTap,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.gray100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.amber400.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                onTap: onTap,
                decoration: const InputDecoration(
                  hintText: 'Search services, gigs, products...',
                  hintStyle: TextStyle(
                    color: AppColors.gray400,
                    fontSize: 14,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: AppColors.amber600,
                    size: 20,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Location
          Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 16,
                color: AppColors.amber600,
              ),
              const SizedBox(width: 8),
              Text(
                locationText,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.gray600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
