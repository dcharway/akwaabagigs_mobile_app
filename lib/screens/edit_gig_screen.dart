import 'package:flutter/material.dart';
import '../models/job.dart';
import '../services/api_service.dart';

class EditGigScreen extends StatefulWidget {
  final Job job;

  const EditGigScreen({super.key, required this.job});

  @override
  State<EditGigScreen> createState() => _EditGigScreenState();
}

class _EditGigScreenState extends State<EditGigScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _companyController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _locationController;
  late final TextEditingController _salaryController;
  late String _employmentType;
  late String? _selectedCategory;
  late String _status;
  bool _isSubmitting = false;

  final _employmentTypes = [
    {'value': 'full-time', 'label': 'Full-time'},
    {'value': 'part-time', 'label': 'Part-time'},
    {'value': 'contract', 'label': 'Contract'},
    {'value': 'remote', 'label': 'Remote'},
  ];

  final _statusOptions = [
    {'value': 'active', 'label': 'Active'},
    {'value': 'pending_service', 'label': 'In Progress'},
    {'value': 'completed', 'label': 'Completed'},
    {'value': 'closed', 'label': 'Closed'},
    {'value': 'inactive', 'label': 'Inactive'},
  ];

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
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.job.title);
    _companyController = TextEditingController(text: widget.job.company);
    _descriptionController =
        TextEditingController(text: widget.job.description);
    _locationController = TextEditingController(text: widget.job.location);
    _salaryController = TextEditingController(text: widget.job.salary);
    _employmentType = widget.job.employmentType;
    _selectedCategory = widget.job.category;
    _status = widget.job.status;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _companyController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _salaryController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      await ApiService.updateJob(widget.job.id, {
        'title': _titleController.text.trim(),
        'company': _companyController.text.trim(),
        'description': _descriptionController.text.trim(),
        'location': _locationController.text.trim(),
        'salary': _salaryController.text.trim(),
        'employmentType': _employmentType,
        'category': _selectedCategory,
        'status': _status,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gig updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
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
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Gig'),
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
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Gig Title',
                  prefixIcon: Icon(Icons.work_outline),
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Title is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _companyController,
                decoration: const InputDecoration(
                  labelText: 'Company Name',
                  prefixIcon: Icon(Icons.business),
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Company is required' : null,
              ),
              const SizedBox(height: 16),
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
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: 'Location',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Location is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _salaryController,
                decoration: const InputDecoration(
                  labelText: 'Pay / Salary',
                  prefixIcon: Icon(Icons.attach_money),
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Salary is required' : null,
              ),
              const SizedBox(height: 16),
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
              DropdownButtonFormField<String>(
                value: _status,
                decoration: const InputDecoration(
                  labelText: 'Status',
                  prefixIcon: Icon(Icons.flag_outlined),
                ),
                items: _statusOptions
                    .map((s) => DropdownMenuItem(
                          value: s['value'],
                          child: Text(s['label']!),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _status = v);
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  alignLabelWithHint: true,
                ),
                maxLines: 5,
                validator: (v) =>
                    v == null || v.isEmpty ? 'Description is required' : null,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isSubmitting ? null : _saveChanges,
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
                      : const Text('Save Changes',
                          style: TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
