import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import 'payment_screen.dart';

class PostGigScreen extends StatefulWidget {
  const PostGigScreen({super.key});

  @override
  State<PostGigScreen> createState() => _PostGigScreenState();
}

class _PostGigScreenState extends State<PostGigScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _companyController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _salaryController = TextEditingController();
  final _requirementController = TextEditingController();

  String _employmentType = 'full-time';
  String? _selectedCategory;
  String? _locationRange;
  final List<String> _requirements = [];
  final List<File> _selectedImages = [];
  bool _isSubmitting = false;

  final _employmentTypes = [
    {'value': 'full-time', 'label': 'Full-time'},
    {'value': 'part-time', 'label': 'Part-time'},
    {'value': 'contract', 'label': 'Contract'},
    {'value': 'remote', 'label': 'Remote'},
  ];

  final _locationRanges = ['5', '10', '15', '25', '50', '100', 'any'];

  final _categoryValues = [
    {'value': 'home-services', 'label': 'Home Services'},
    {'value': 'transportation', 'label': 'Transportation'},
    {'value': 'events', 'label': 'Events'},
    {'value': 'beauty-wellness', 'label': 'Beauty & Wellness'},
    {'value': 'tech-digital', 'label': 'Tech & Digital'},
    {'value': 'education', 'label': 'Education'},
    {'value': 'construction', 'label': 'Construction'},
    {'value': 'agriculture', 'label': 'Agriculture'},
    {'value': 'business', 'label': 'Business'},
    {'value': 'security', 'label': 'Security'},
    {'value': 'health', 'label': 'Health'},
    {'value': 'other', 'label': 'Other'},
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _companyController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _salaryController.dispose();
    _requirementController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    if (_selectedImages.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 5 images allowed')),
      );
      return;
    }

    final picker = ImagePicker();
    final images = await picker.pickMultiImage(
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 80,
    );

    if (images.isNotEmpty) {
      final remaining = 5 - _selectedImages.length;
      final toAdd = images.take(remaining).map((x) => File(x.path)).toList();
      setState(() {
        _selectedImages.addAll(toAdd);
      });
    }
  }

  void _addRequirement() {
    final text = _requirementController.text.trim();
    if (text.isNotEmpty) {
      setState(() {
        _requirements.add(text);
        _requirementController.clear();
      });
    }
  }

  Future<void> _submitGig() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      List<String>? imageUrls;
      if (_selectedImages.isNotEmpty) {
        imageUrls = await ApiService.uploadGigImages(_selectedImages);
      }

      // Create job as pending_payment — won't go live until payment
      final job = await ApiService.createJob(
        title: _titleController.text.trim(),
        company: _companyController.text.trim(),
        description: _descriptionController.text.trim(),
        location: _locationController.text.trim(),
        salary: _salaryController.text.trim(),
        employmentType: _employmentType,
        category: _selectedCategory,
        locationRange: _locationRange,
        requirements: _requirements.isNotEmpty ? _requirements : null,
        gigImages: imageUrls,
      );

      if (mounted) {
        // Set status to pending_payment before redirecting
        await ApiService.updateJob(job.id, {'status': 'pending_payment'});

        // Navigate to payment screen
        final paid = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => PaymentScreen(job: job),
          ),
        );

        if (mounted) {
          if (paid == true) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Gig posted and payment completed!'),
                backgroundColor: Colors.green,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    'Gig saved as draft. Complete payment to go live.'),
              ),
            );
          }
          Navigator.pop(context, paid == true);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Post a Gig'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Gig Details',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),

              // Title
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Gig Title',
                  hintText: 'e.g., House Cleaning in East Legon',
                  prefixIcon: Icon(Icons.work_outline),
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Title is required' : null,
              ),
              const SizedBox(height: 16),

              // Company
              TextFormField(
                controller: _companyController,
                decoration: const InputDecoration(
                  labelText: 'Business / Company Name',
                  prefixIcon: Icon(Icons.business),
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Company name is required' : null,
              ),
              const SizedBox(height: 16),

              // Category
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: _categoryValues
                    .map((c) => DropdownMenuItem(
                          value: c['value'],
                          child: Text(c['label']!),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _selectedCategory = v),
              ),
              const SizedBox(height: 16),

              // Location
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: 'Location',
                  hintText: 'e.g., Accra, Greater Accra',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Location is required' : null,
              ),
              const SizedBox(height: 16),

              // Location Range
              DropdownButtonFormField<String>(
                value: _locationRange,
                decoration: const InputDecoration(
                  labelText: 'Location Range (km)',
                  prefixIcon: Icon(Icons.radar),
                ),
                items: _locationRanges
                    .map((r) => DropdownMenuItem(
                          value: r,
                          child: Text(r == 'any' ? 'Any distance' : '$r km'),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _locationRange = v),
              ),
              const SizedBox(height: 16),

              // Salary
              TextFormField(
                controller: _salaryController,
                decoration: const InputDecoration(
                  labelText: 'Pay / Salary',
                  hintText: 'e.g., GH₵500/day or Negotiable',
                  prefixIcon: Icon(Icons.payments_outlined),
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Salary is required' : null,
              ),
              const SizedBox(height: 16),

              // Employment Type
              DropdownButtonFormField<String>(
                value: _employmentType,
                decoration: const InputDecoration(
                  labelText: 'Employment Type',
                  prefixIcon: Icon(Icons.schedule),
                ),
                items: _employmentTypes
                    .map((t) => DropdownMenuItem(
                          value: t['value'],
                          child: Text(t['label']!),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _employmentType = v);
                },
              ),
              const SizedBox(height: 16),

              // Description
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Describe the gig in detail...',
                  alignLabelWithHint: true,
                ),
                maxLines: 5,
                validator: (v) =>
                    v == null || v.isEmpty ? 'Description is required' : null,
              ),
              const SizedBox(height: 24),

              // Requirements
              Text(
                'Requirements',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _requirementController,
                      decoration: const InputDecoration(
                        hintText: 'Add a requirement...',
                      ),
                      onSubmitted: (_) => _addRequirement(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _addRequirement,
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
              if (_requirements.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: _requirements.asMap().entries.map((entry) {
                    return Chip(
                      label: Text(entry.value),
                      onDeleted: () {
                        setState(() => _requirements.removeAt(entry.key));
                      },
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 24),

              // Images
              Text(
                'Gig Images (${_selectedImages.length}/5)',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              if (_selectedImages.isNotEmpty)
                SizedBox(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _selectedImages.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                _selectedImages[index],
                                width: 100,
                                height: 100,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () {
                                  setState(() =>
                                      _selectedImages.removeAt(index));
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _pickImages,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: const Text('Add Images'),
              ),
              const SizedBox(height: 32),

              // Submit
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isSubmitting ? null : _submitGig,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Post Gig',
                          style: TextStyle(fontSize: 16),
                        ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
