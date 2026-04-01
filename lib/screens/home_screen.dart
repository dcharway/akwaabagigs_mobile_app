import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/colors.dart';
import '../providers/jobs_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/notifications_provider.dart';
import '../models/job.dart';
import '../widgets/job_card.dart';
import '../widgets/header_widget.dart';
import '../widgets/search_bar_widget.dart';
import '../widgets/ad_carousel_widget.dart';
import '../widgets/quick_stats_widget.dart';
import '../widgets/popular_gigs_widget.dart';
import '../widgets/services_grid_widget.dart';
import 'job_details_screen.dart';
import 'chat_list_screen.dart';
import 'profile_screen.dart';
import 'notifications_screen.dart';
import 'post_gig_screen.dart';
import 'my_gigs_screen.dart';
import 'my_applications_screen.dart';
import 'saved_gigs_screen.dart';
import 'store_screen.dart';
import 'admin_video_ads_screen.dart';
import 'customer_support_screen.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final TextEditingController _searchController = TextEditingController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

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

  void _switchToGigsTab() {
    setState(() {
      _currentIndex = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final notifProvider = context.watch<NotificationsProvider>();

    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildDrawer(context, authProvider),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildHomeLanding(),
          _buildGigsTab(),
          const StoreScreen(),
          const ChatListScreen(),
          const NotificationsScreen(),
          const ProfileScreen(),
        ],
      ),
      floatingActionButton: _currentIndex == 1
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.amber600,
              foregroundColor: Colors.white,
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
      bottomNavigationBar: _buildBottomNav(notifProvider),
    );
  }

  // ============ DRAWER ============

  Widget _buildDrawer(BuildContext context, AuthProvider authProvider) {
    return Drawer(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.amber50, Colors.white],
          ),
        ),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.amber600, AppColors.amber900],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.2),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/icon/app_icon.png',
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    authProvider.isAuthenticated
                        ? authProvider.user?.fullName ?? 'User'
                        : 'Welcome to Akwaaba',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (authProvider.isAuthenticated)
                    Text(
                      authProvider.user?.email ?? '',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            if (authProvider.isAuthenticated) ...[
              _drawerItem(
                icon: Icons.bookmark_outline,
                label: 'Saved Gigs',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SavedGigsScreen()),
                  );
                },
              ),
              _drawerItem(
                icon: Icons.work_history_outlined,
                label: 'My Posted Gigs',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MyGigsScreen()),
                  );
                },
              ),
              _drawerItem(
                icon: Icons.assignment_outlined,
                label: 'My Applications',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const MyApplicationsScreen()),
                  );
                },
              ),
              if (authProvider.user?.isAdmin == true) ...[
                const Divider(color: AppColors.gray200),
                _drawerItem(
                  icon: Icons.videocam,
                  label: 'Video Ads Manager',
                  color: AppColors.red600,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              const AdminVideoAdsScreen()),
                    );
                  },
                ),
              ],
              _drawerItem(
                icon: Icons.smart_toy,
                label: 'Help & Support',
                color: AppColors.amber600,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            const CustomerSupportScreen()),
                  );
                },
              ),
              const Divider(color: AppColors.gray200),
              _drawerItem(
                icon: Icons.logout,
                label: 'Logout',
                color: AppColors.red600,
                onTap: () {
                  Navigator.pop(context);
                  authProvider.logout();
                },
              ),
            ] else ...[
              _drawerItem(
                icon: Icons.login,
                label: 'Login / Register',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                },
              ),
              _drawerItem(
                icon: Icons.smart_toy,
                label: 'Help & Support',
                color: AppColors.amber600,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            const CustomerSupportScreen()),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _drawerItem({
    required IconData icon,
    required String label,
    Color? color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: color ?? AppColors.gray700),
      title: Text(
        label,
        style: TextStyle(color: color ?? AppColors.gray800),
      ),
      onTap: onTap,
    );
  }

  // ============ BOTTOM NAVIGATION ============

  Widget _buildBottomNav(NotificationsProvider notifProvider) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                icon: Icons.home_outlined,
                activeIcon: Icons.home,
                label: 'Home',
                index: 0,
              ),
              _buildNavItem(
                icon: Icons.work_outline,
                activeIcon: Icons.work,
                label: 'Gigs',
                index: 1,
              ),
              _buildNavItem(
                icon: Icons.shopping_bag_outlined,
                activeIcon: Icons.shopping_bag,
                label: 'Store',
                index: 2,
              ),
              _buildNavItem(
                icon: Icons.chat_bubble_outline,
                activeIcon: Icons.chat_bubble,
                label: 'Chat',
                index: 3,
              ),
              _buildNavItem(
                icon: Icons.notifications_outlined,
                activeIcon: Icons.notifications,
                label: 'Alerts',
                index: 4,
                badgeCount: notifProvider.unreadCount,
              ),
              _buildNavItem(
                icon: Icons.person_outline,
                activeIcon: Icons.person,
                label: 'Profile',
                index: 5,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int index,
    int badgeCount = 0,
  }) {
    final isActive = _currentIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
      },
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isActive
                        ? AppColors.amber500.withOpacity(0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    isActive ? activeIcon : icon,
                    color: isActive ? AppColors.amber700 : AppColors.gray500,
                    size: 24,
                  ),
                ),
                if (badgeCount > 0)
                  Positioned(
                    right: 4,
                    top: -2,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppColors.red500,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        '$badgeCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                color: isActive ? AppColors.amber700 : AppColors.gray500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============ HOME LANDING TAB ============

  Widget _buildHomeLanding() {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.backgroundGradient,
      ),
      child: SafeArea(
        child: RefreshIndicator(
          color: AppColors.amber600,
          onRefresh: () => context.read<JobsProvider>().loadJobs(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                HeaderWidget(
                  onMenuTap: () {
                    _scaffoldKey.currentState?.openDrawer();
                  },
                  onChatTap: () {
                    setState(() => _currentIndex = 3); // Chat tab
                  },
                ),

                // Search Bar
                SearchBarWidget(
                  onTap: _switchToGigsTab,
                ),

                // Ad Carousel
                const AdCarouselWidget(),

                // Services Grid
                ServicesGridWidget(
                  onGigsTap: _switchToGigsTab,
                  onStoreTap: () {
                    setState(() => _currentIndex = 2);
                  },
                ),

                // Quick Stats
                const QuickStatsWidget(),

                // Popular Gigs
                PopularGigsWidget(
                  onSeeAllTap: _switchToGigsTab,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============ GIGS TAB (Browse) ============

  Widget _buildGigsTab() {
    return Container(
      color: AppColors.gray100,
      child: Consumer<JobsProvider>(
        builder: (context, jobsProvider, child) {
          return RefreshIndicator(
            color: AppColors.amber600,
            onRefresh: () => jobsProvider.loadJobs(),
            child: CustomScrollView(
              slivers: [
                // Custom App Bar
                SliverAppBar(
                  floating: true,
                  snap: true,
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.gray900,
                  elevation: 0,
                  title: const Text(
                    'Browse Gigs',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.amber900,
                    ),
                  ),
                  actions: [
                    if (context.watch<AuthProvider>().isAuthenticated)
                      IconButton(
                        icon: const Icon(Icons.bookmark_border,
                            color: AppColors.amber600),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const SavedGigsScreen()),
                        ),
                        tooltip: 'Saved Gigs',
                      ),
                  ],
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Search
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.amber400.withOpacity(0.3),
                              width: 1.5,
                            ),
                          ),
                          child: TextField(
                            controller: _searchController,
                            decoration: const InputDecoration(
                              hintText: 'Search gigs...',
                              hintStyle: TextStyle(color: AppColors.gray400),
                              prefixIcon: Icon(Icons.search,
                                  color: AppColors.amber600),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                            onChanged: (value) {
                              jobsProvider.setSearchQuery(value);
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildFilters(jobsProvider),
                      ],
                    ),
                  ),
                ),
                if (jobsProvider.isLoading)
                  const SliverFillRemaining(
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppColors.amber600,
                      ),
                    ),
                  )
                else if (jobsProvider.error != null)
                  SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 64,
                            color: AppColors.red500,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Failed to load gigs',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: AppColors.gray800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          FilledButton(
                            onPressed: () => jobsProvider.loadJobs(),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.amber600,
                            ),
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
                          const Icon(
                            Icons.work_off_outlined,
                            size: 64,
                            color: AppColors.gray400,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No gigs found',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: AppColors.gray800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Try adjusting your filters',
                            style: TextStyle(
                              color: AppColors.gray500,
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
      ),
    );
  }

  Widget _buildFilters(JobsProvider jobsProvider) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildFilterChip(
            label: jobsProvider.selectedCategory ?? 'Category',
            isSelected: jobsProvider.selectedCategory != null,
            onTap: () => _showCategoryPicker(jobsProvider),
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            label: jobsProvider.selectedLocation ?? 'Location',
            isSelected: jobsProvider.selectedLocation != null,
            onTap: () => _showLocationPicker(jobsProvider),
          ),
          const SizedBox(width: 8),
          if (jobsProvider.selectedCategory != null ||
              jobsProvider.selectedLocation != null ||
              jobsProvider.searchQuery.isNotEmpty)
            GestureDetector(
              onTap: () {
                jobsProvider.clearFilters();
                _searchController.clear();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.red50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.red500.withOpacity(0.3)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.clear, size: 14, color: AppColors.red600),
                    SizedBox(width: 4),
                    Text(
                      'Clear',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.red600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.amber500.withOpacity(0.15) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.amber500 : AppColors.gray200,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: isSelected ? AppColors.amber700 : AppColors.gray600,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down,
              size: 16,
              color: isSelected ? AppColors.amber700 : AppColors.gray500,
            ),
          ],
        ),
      ),
    );
  }

  void _showCategoryPicker(JobsProvider jobsProvider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.gray200,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                title: const Text(
                  'All Categories',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                onTap: () {
                  jobsProvider.setCategory(null);
                  Navigator.pop(context);
                },
              ),
              const Divider(height: 1),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: JobsProvider.categories.length,
                  itemBuilder: (context, index) {
                    final category = JobsProvider.categories[index];
                    final isSelected =
                        jobsProvider.selectedCategory == category;
                    return ListTile(
                      title: Text(
                        category,
                        style: TextStyle(
                          color: isSelected
                              ? AppColors.amber700
                              : AppColors.gray800,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check, color: AppColors.amber600)
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
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.gray200,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                title: const Text(
                  'All Locations',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                onTap: () {
                  jobsProvider.setLocation(null);
                  Navigator.pop(context);
                },
              ),
              const Divider(height: 1),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: JobsProvider.ghanaRegions.length,
                  itemBuilder: (context, index) {
                    final region = JobsProvider.ghanaRegions[index];
                    final isSelected =
                        jobsProvider.selectedLocation == region;
                    return ListTile(
                      title: Text(
                        region,
                        style: TextStyle(
                          color: isSelected
                              ? AppColors.amber700
                              : AppColors.gray800,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check, color: AppColors.amber600)
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
