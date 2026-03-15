import 'package:flutter/material.dart';
import '../models/job.dart';
import '../services/back4app_service.dart';

class JobsProvider extends ChangeNotifier {
  List<Job> _jobs = [];
  bool _isLoading = false;
  String? _error;
  String _searchQuery = '';
  String? _selectedCategory;
  String? _selectedLocation;

  List<Job> get jobs => _filteredJobs;
  List<Job> get allJobs => _jobs;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get searchQuery => _searchQuery;
  String? get selectedCategory => _selectedCategory;
  String? get selectedLocation => _selectedLocation;

  List<Job> get _filteredJobs {
    var filtered = _jobs.where((job) => job.status == 'active').toList();
    
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
    notifyListeners();

    try {
      _jobs = await Back4AppService.getJobs();
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setCategory(String? category) {
    _selectedCategory = category;
    notifyListeners();
  }

  void setLocation(String? location) {
    _selectedLocation = location;
    notifyListeners();
  }

  void clearFilters() {
    _searchQuery = '';
    _selectedCategory = null;
    _selectedLocation = null;
    notifyListeners();
  }

  Job? getJobById(String id) {
    try {
      return _jobs.firstWhere((job) => job.id == id);
    } catch (e) {
      return null;
    }
  }
}
