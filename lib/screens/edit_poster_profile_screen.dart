import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/gig_poster.dart';
import '../services/api_service.dart';
import '../utils/app_notifier.dart';

class EditPosterProfileScreen extends StatefulWidget {
  final GigPoster? profile;

  const EditPosterProfileScreen({super.key, this.profile});

  @override
  State<EditPosterProfileScreen> createState() =>
      _EditPosterProfileScreenState();
}

class _EditPosterProfileScreenState extends State<EditPosterProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _businessNameController;
  late final TextEditingController _businessDescriptionController;
  late final TextEditingController _contactEmailController;
  late final TextEditingController _contactPhoneController;
  late final TextEditingController _locationController;
  late final TextEditingController _websiteController;
  File? _profileImage;
  File? _ghCardImage;
  bool _isSubmitting = false;
  bool _isNew = false;

  @override
  void initState() {
    super.initState();
    _isNew = widget.profile == null;
    _businessNameController =
        TextEditingController(text: widget.profile?.businessName ?? '');
    _businessDescriptionController =
        TextEditingController(text: widget.profile?.businessDescription ?? '');
    _contactEmailController =
        TextEditingController(text: widget.profile?.contactEmail ?? '');
    _contactPhoneController =
        TextEditingController(text: widget.profile?.contactPhone ?? '');
    _locationController =
        TextEditingController(text: widget.profile?.location ?? '');
    _websiteController = TextEditingController();
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _businessDescriptionController.dispose();
    _contactEmailController.dispose();
    _contactPhoneController.dispose();
    _locationController.dispose();
    _websiteController.dispose();
    super.dispose();
  }

  Future<void> _pickProfileImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 600,
      maxHeight: 600,
      imageQuality: 80,
    );
    if (image != null) {
      setState(() => _profileImage = File(image.path));
    }
  }

  Future<void> _pickGhCard() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 85,
    );
    if (image != null) {
      setState(() => _ghCardImage = File(image.path));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      if (_isNew) {
        await ApiService.createGigPosterProfile(
          businessName: _businessNameController.text.trim(),
          businessDescription:
              _businessDescriptionController.text.trim().isNotEmpty
                  ? _businessDescriptionController.text.trim()
                  : null,
          contactEmail: _contactEmailController.text.trim(),
          contactPhone: _contactPhoneController.text.trim(),
          location: _locationController.text.trim(),
          website: _websiteController.text.trim().isNotEmpty
              ? _websiteController.text.trim()
              : null,
        );
      } else {
        await ApiService.updateGigPosterProfile({
          'businessName': _businessNameController.text.trim(),
          'businessDescription':
              _businessDescriptionController.text.trim(),
          'contactEmail': _contactEmailController.text.trim(),
          'contactPhone': _contactPhoneController.text.trim(),
          'location': _locationController.text.trim(),
        });
      }

      if (_profileImage != null) {
        await ApiService.uploadProfilePicture(_profileImage!, isPoster: true);
      }

      if (_ghCardImage != null) {
        await ApiService.uploadGhCard(_ghCardImage!);
      }

      if (mounted) {
        AppNotifier.success(context,
            _isNew ? 'Poster profile created!' : 'Profile updated!');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        AppNotifier.error(
            context, e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'Create Poster Profile' : 'Edit Poster Profile'),
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
              Center(
                child: GestureDetector(
                  onTap: _pickProfileImage,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor:
                            Theme.of(context).colorScheme.primaryContainer,
                        backgroundImage: _profileImage != null
                            ? FileImage(_profileImage!)
                            : (widget.profile?.profilePictureUrl != null
                                    ? NetworkImage(
                                        widget.profile!.profilePictureUrl!)
                                    : null)
                                as ImageProvider?,
                        child: _profileImage == null &&
                                widget.profile?.profilePictureUrl == null
                            ? Icon(Icons.business,
                                size: 40,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onPrimaryContainer)
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.camera_alt,
                              size: 16,
                              color: Theme.of(context).colorScheme.onPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              TextFormField(
                controller: _businessNameController,
                decoration: const InputDecoration(
                  labelText: 'Business Name',
                  prefixIcon: Icon(Icons.business),
                ),
                validator: (v) => v == null || v.isEmpty
                    ? 'Business name is required'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _businessDescriptionController,
                decoration: const InputDecoration(
                  labelText: 'Business Description',
                  alignLabelWithHint: true,
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _contactEmailController,
                decoration: const InputDecoration(
                  labelText: 'Contact Email',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Email is required';
                  if (!v.contains('@')) return 'Enter a valid email';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _contactPhoneController,
                decoration: const InputDecoration(
                  labelText: 'Contact Phone',
                  prefixIcon: Icon(Icons.phone_outlined),
                  hintText: '+233...',
                ),
                keyboardType: TextInputType.phone,
                validator: (v) =>
                    v == null || v.isEmpty ? 'Phone is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: 'Location',
                  prefixIcon: Icon(Icons.location_on_outlined),
                  hintText: 'e.g., Accra, Greater Accra',
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Location is required' : null,
              ),
              if (_isNew) ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _websiteController,
                  decoration: const InputDecoration(
                    labelText: 'Website (optional)',
                    prefixIcon: Icon(Icons.language),
                  ),
                  keyboardType: TextInputType.url,
                ),
              ],
              const SizedBox(height: 24),

              // GH Card
              Text(
                'Ghana Card (for verification)',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Upload your Ghana Card to verify your business identity.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
              const SizedBox(height: 12),
              if (_ghCardImage != null)
                Container(
                  height: 120,
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    image: DecorationImage(
                      image: FileImage(_ghCardImage!),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              OutlinedButton.icon(
                onPressed: _pickGhCard,
                icon: const Icon(Icons.upload_file),
                label: Text(_ghCardImage != null
                    ? 'Change Ghana Card'
                    : 'Upload Ghana Card'),
              ),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isSubmitting ? null : _save,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Text(_isNew ? 'Create Profile' : 'Save Changes',
                          style: const TextStyle(fontSize: 16)),
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
