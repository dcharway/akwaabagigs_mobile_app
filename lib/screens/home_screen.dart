import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/jobs_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/notifications_provider.dart';
import '../models/job.dart';
import '../widgets/job_card.dart';
import 'job_details_screen.dart';
import 'chat_list_screen.dart';
import 'profile_screen.dart';
import 'notifications_screen.dart';
import 'post_gig_screen.dart';
import 'my_gigs_screen.dart';
import 'my_applications_screen.dart';
import 'saved_gigs_screen.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<JobsProvider>().loadJobs();
      context.read<NotificationsProvider>().connect();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final notifProvider = context.watch<NotificationsProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Akwaaba Gigs',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        elevation: 0,
        actions: [
          if (authProvider.isAuthenticated) ...[
            IconButton(
              icon: const Icon(Icons.bookmark_border),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SavedGigsScreen()),
              ),
              tooltip: 'Saved Gigs',
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                switch (value) {
                  case 'my_gigs':
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const MyGigsScreen()),
                    );
                    break;
                  case 'my_applications':
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              const MyApplicationsScreen()),
                    );
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'my_gigs',
                  child: Row(
                    children: [
                      Icon(Icons.work_history_outlined),
                      SizedBox(width: 8),
                      Text('My Posted Gigs'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'my_applications',
                  child: Row(
                    children: [
                      Icon(Icons.assignment_outlined),
                      SizedBox(width: 8),
                      Text('My Applications'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildJobsTab(),
          const ChatListScreen(),
          const NotificationsScreen(),
          const ProfileScreen(),
        ],
      ),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton.extended(
              onPressed: () async {
                if (!authProvider.isAuthenticated) {
                  final loggedIn = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const LoginScreen()),
                  );
                  if (loggedIn != true) return;
                }
                if (!context.mounted) return;
                final posted = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const PostGigScreen()),
                );
                if (posted == true) {
                  if (context.mounted) {
                    context.read<JobsProvider>().loadJobs();
                  }
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('Post Gig'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.work_outline),
            selectedIcon: Icon(Icons.work),
            label: 'Gigs',
          ),
          const NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: 'Messages',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: notifProvider.unreadCount > 0,
              label: Text('${notifProvider.unreadCount}'),
              child: const Icon(Icons.notifications_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: notifProvider.unreadCount > 0,
              label: Text('${notifProvider.unreadCount}'),
              child: const Icon(Icons.notifications),
            ),
            label: 'Alerts',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _buildJobsTab() {
    return Consumer<JobsProvider>(
      builder: (context, jobsProvider, child) {
        return RefreshIndicator(
          onRefresh: () => jobsProvider.loadJobs(),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search gigs...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surface,
                        ),
                        onChanged: (value) {
                          jobsProvider.setSearchQuery(value);
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildFilters(jobsProvider),
                    ],
                  ),
                ),
              ),
              if (jobsProvider.isLoading)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (jobsProvider.error != null)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Failed to load gigs',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: () => jobsProvider.loadJobs(),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              else if (jobsProvider.jobs.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.work_off_outlined,
                          size: 64,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No gigs found',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Try adjusting your filters',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                color:
                                    Theme.of(context).colorScheme.outline,
                              ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final job = jobsProvider.jobs[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: JobCard(
                            job: job,
                            onTap: () => _navigateToJobDetails(job),
                          ),
                        );
                      },
                      childCount: jobsProvider.jobs.length,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilters(JobsProvider jobsProvider) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          FilterChip(
            label: Text(jobsProvider.selectedCategory ?? 'Category'),
            selected: jobsProvider.selectedCategory != null,
            onSelected: (_) => _showCategoryPicker(jobsProvider),
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: Text(jobsProvider.selectedLocation ?? 'Location'),
            selected: jobsProvider.selectedLocation != null,
            onSelected: (_) => _showLocationPicker(jobsProvider),
          ),
          const SizedBox(width: 8),
          if (jobsProvider.selectedCategory != null ||
              jobsProvider.selectedLocation != null ||
              jobsProvider.searchQuery.isNotEmpty)
            ActionChip(
              label: const Text('Clear'),
              onPressed: () {
                jobsProvider.clearFilters();
                _searchController.clear();
              },
            ),
        ],
      ),
    );
  }

  void _showCategoryPicker(JobsProvider jobsProvider) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('All Categories'),
                onTap: () {
                  jobsProvider.setCategory(null);
                  Navigator.pop(context);
                },
              ),
              const Divider(),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: JobsProvider.categories.length,
                  itemBuilder: (context, index) {
                    final category = JobsProvider.categories[index];
                    return ListTile(
                      title: Text(category),
                      trailing: jobsProvider.selectedCategory == category
                          ? const Icon(Icons.check)
                          : null,
                      onTap: () {
                        jobsProvider.setCategory(category);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showLocationPicker(JobsProvider jobsProvider) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('All Locations'),
                onTap: () {
                  jobsProvider.setLocation(null);
                  Navigator.pop(context);
                },
              ),
              const Divider(),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: JobsProvider.ghanaRegions.length,
                  itemBuilder: (context, index) {
                    final region = JobsProvider.ghanaRegions[index];
                    return ListTile(
                      title: Text(region),
                      trailing: jobsProvider.selectedLocation == region
                          ? const Icon(Icons.check)
                          : null,
                      onTap: () {
                        jobsProvider.setLocation(region);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _navigateToJobDetails(Job job) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => JobDetailsScreen(job: job),
      ),
    );
  }
}
