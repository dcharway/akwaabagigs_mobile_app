import 'package:flutter/material.dart';
import '../models/job.dart';
import '../services/api_service.dart';

class JobsProvider extends ChangeNotifier {
  List<Job> _jobs = [];
  List<Job>? _filteredCache;
  bool _isLoading = false;
  String? _error;
  String _searchQuery = '';
  String? _selectedCategory;
  String? _selectedLocation;

  List<Job> get jobs => _filteredCache ??= _computeFiltered();
  List<Job> get allJobs => _jobs;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get searchQuery => _searchQuery;
  String? get selectedCategory => _selectedCategory;
  String? get selectedLocation => _selectedLocation;

  void _invalidateCache() => _filteredCache = null;

  List<Job> _computeFiltered() {
    var filtered = _jobs
        .where((job) => job.status == 'active' || job.status == 'bid_agreed')
        .toList();

    filtered.sort((a, b) {
      if (a.isCurrentlyFeatured && !b.isCurrentlyFeatured) return -1;
      if (!a.isCurrentlyFeatured && b.isCurrentlyFeatured) return 1;
      if (a.isUrgent && !b.isUrgent) return -1;
      if (!a.isUrgent && b.isUrgent) return 1;
      return b.postedDate.compareTo(a.postedDate);
    });

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((job) =>
        job.title.toLowerCase().contains(query) ||
        job.company.toLowerCase().contains(query) ||
        job.description.toLowerCase().contains(query)
      ).toList();
    }

    if (_selectedCategory != null && _selectedCategory!.isNotEmpty) {
      filtered = filtered.where((job) =>
        job.category?.toLowerCase() == _selectedCategory!.toLowerCase()
      ).toList();
    }

    if (_selectedLocation != null && _selectedLocation!.isNotEmpty) {
      filtered = filtered.where((job) =>
        job.location.toLowerCase().contains(_selectedLocation!.toLowerCase())
      ).toList();
    }

    return filtered;
  }

  static const List<String> categories = [
    'Home Services',
    'Transportation',
    'Events',
    'Beauty & Wellness',
    'Tech & Digital',
    'Education',
    'Construction',
    'Agriculture',
    'Business',
    'Security',
    'Health',
    'Other',
  ];

  static const List<String> ghanaRegions = [
    'Greater Accra',
    'Ashanti',
    'Western',
    'Eastern',
    'Central',
    'Volta',
    'Northern',
    'Upper East',
    'Upper West',
    'Bono',
    'Bono East',
    'Ahafo',
    'Western North',
    'Oti',
    'North East',
    'Savannah',
  ];

  Future<void> loadJobs() async {
    if (_isLoading) return;

    _isLoading = true;
    _error = null;
    _invalidateCache();
    notifyListeners();

    try {
      _jobs = await ApiService.getJobs();
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    _invalidateCache();
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    _invalidateCache();
    notifyListeners();
  }

  void setCategory(String? category) {
    _selectedCategory = category;
    _invalidateCache();
    notifyListeners();
  }

  void setLocation(String? location) {
    _selectedLocation = location;
    _invalidateCache();
    notifyListeners();
  }

  void clearFilters() {
    _searchQuery = '';
    _selectedCategory = null;
    _selectedLocation = null;
    _invalidateCache();
    notifyListeners();
  }

  Job? getJobById(String id) {
    for (final job in _jobs) {
      if (job.id == id) return job;
    }
    return null;
  }
}
