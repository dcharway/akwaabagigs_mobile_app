import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/gig_seeker.dart';
import '../services/api_service.dart';
import '../utils/app_notifier.dart';

class EditSeekerProfileScreen extends StatefulWidget {
  final GigSeeker? profile;

  const EditSeekerProfileScreen({super.key, this.profile});

  @override
  State<EditSeekerProfileScreen> createState() =>
      _EditSeekerProfileScreenState();
}

class _EditSeekerProfileScreenState extends State<EditSeekerProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _fullNameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _locationController;
  File? _profileImage;
  File? _idDocument;
  String? _idDocumentType;
  bool _isSubmitting = false;
  bool _isNew = false;

  final _idDocTypes = [
    {'value': 'ghana_card', 'label': 'Ghana Card'},
    {'value': 'passport', 'label': 'Passport'},
    {'value': 'voter_id', 'label': "Voter's ID"},
    {'value': 'drivers_license', 'label': "Driver's License"},
  ];

  @override
  void initState() {
    super.initState();
    _isNew = widget.profile == null;
    _fullNameController =
        TextEditingController(text: widget.profile?.fullName ?? '');
    _emailController =
        TextEditingController(text: widget.profile?.email ?? '');
    _phoneController =
        TextEditingController(text: widget.profile?.phone ?? '');
    _locationController =
        TextEditingController(text: widget.profile?.location ?? '');
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
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

  Future<void> _pickIdDocument() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 85,
    );
    if (image != null) {
      setState(() => _idDocument = File(image.path));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      if (_isNew) {
        await ApiService.registerGigSeeker(
          email: _emailController.text.trim(),
          fullName: _fullNameController.text.trim(),
          phone: _phoneController.text.trim(),
          location: _locationController.text.trim(),
        );
      } else {
        await ApiService.updateGigSeekerProfile({
          'fullName': _fullNameController.text.trim(),
          'phone': _phoneController.text.trim(),
          'location': _locationController.text.trim(),
        });
      }

      if (_profileImage != null) {
        await ApiService.uploadProfilePicture(_profileImage!, isPoster: false);
      }

      if (_idDocument != null && _idDocumentType != null) {
        await ApiService.uploadIdDocument(
          _idDocument!,
          email: _emailController.text.trim(),
        );
      }

      if (mounted) {
        AppNotifier.success(context,
            _isNew ? 'Seeker profile created!' : 'Profile updated!');
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
        title: Text(_isNew ? 'Create Seeker Profile' : 'Edit Seeker Profile'),
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
              // Profile picture
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
                            ? Icon(
                                Icons.person,
                                size: 40,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onPrimaryContainer,
                              )
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
                          child: Icon(
                            Icons.camera_alt,
                            size: 16,
                            color:
                                Theme.of(context).colorScheme.onPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              TextFormField(
                controller: _fullNameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Name is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                keyboardType: TextInputType.emailAddress,
                enabled: _isNew,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Email is required';
                  if (!v.contains('@')) return 'Enter a valid email';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
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
              const SizedBox(height: 24),

              // ID Document section
              Text(
                'ID Verification',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Upload an ID document to get verified and unlock chat features.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _idDocumentType,
                decoration: const InputDecoration(
                  labelText: 'ID Document Type',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                items: _idDocTypes
                    .map((t) => DropdownMenuItem(
                          value: t['value'],
                          child: Text(t['label']!),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _idDocumentType = v),
              ),
              const SizedBox(height: 8),
              if (_idDocument != null)
                Container(
                  height: 120,
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    image: DecorationImage(
                      image: FileImage(_idDocument!),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              OutlinedButton.icon(
                onPressed: _pickIdDocument,
                icon: const Icon(Icons.upload_file),
                label: Text(
                    _idDocument != null ? 'Change Document' : 'Upload ID'),
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
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
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
