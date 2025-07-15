import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'services/admin_service.dart';
import 'plan_detail_screen.dart';
import 'user_management_screen.dart';
import 'services/auth_service.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  _AdminScreenState createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> with SingleTickerProviderStateMixin {
  final AdminService _adminService = AdminService();
  final AuthService _authService = AuthService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _usersWithPlans = [];
  Map<String, dynamic> _statistics = {};
  late TabController _tabController;
  final GlobalKey<UserManagementScreenState> _userManagementKey = GlobalKey<UserManagementScreenState>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final users = await _adminService.getAllUsersWithDietPlans();
      final stats = await _adminService.getUserStatistics();
      setState(() {
        _usersWithPlans = users;
        _statistics = stats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('Failed to load data: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _deleteDietPlan(String userId, int planIndex, String userName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Diet Plan'),
        content: Text('Are you sure you want to delete this diet plan from $userName?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _adminService.deleteDietPlan(userId, planIndex);
        _showSuccessSnackBar('Diet plan deleted successfully');
        _loadData(); // Reload data
      } catch (e) {
        _showErrorSnackBar('Failed to delete diet plan: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Admin Dashboard'),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(
              icon: Icon(Icons.restaurant_menu),
              text: 'Diet Plans',
            ),
            Tab(
              icon: Icon(Icons.people),
              text: 'User Management',
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              if (_tabController.index == 0) {
                _loadData();
              } else if (_tabController.index == 1) {
                _userManagementKey.currentState?.loadUsers();
              }
            },
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              await _authService.signOut();
              if (mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
              }
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Diet Plans Tab
          _buildDietPlansTab(),
          // User Management Tab
          UserManagementScreen(key: _userManagementKey),
        ],
      ),
    );
  }

  Widget _buildDietPlansTab() {
    return _isLoading
          ? Center(child: CircularProgressIndicator())
          : Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.red.shade50, Colors.red.shade100],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                children: [
                  // Statistics Cards
                  _buildStatisticsCards(),
                  
                  // Users with Diet Plans
                  Expanded(
                    child: _usersWithPlans.isEmpty
                        ? _buildEmptyState()
                        : _buildUsersList(),
                  ),
                ],
            ),
    );
  }

  Widget _buildStatisticsCards() {
    return Container(
      padding: EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              'Total Users',
              _statistics['totalUsers']?.toString() ?? '0',
              Icons.people,
              Colors.blue,
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: _buildStatCard(
              'Users with Plans',
              _statistics['usersWithDietPlans']?.toString() ?? '0',
              Icons.restaurant_menu,
              Colors.green,
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: _buildStatCard(
              'Total Plans',
              _statistics['totalDietPlans']?.toString() ?? '0',
              Icons.receipt_long,
              Colors.orange,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.admin_panel_settings, size: 80, color: Colors.red.shade300),
          SizedBox(height: 16),
          Text(
            'No Diet Plans Found',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.red.shade700,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Users will appear here once they create diet plans.',
            style: TextStyle(fontSize: 16, color: Colors.red.shade600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildUsersList() {
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _usersWithPlans.length,
      itemBuilder: (context, userIndex) {
        final user = _usersWithPlans[userIndex];
        final List<dynamic> dietPlans = user['dietPlans'];
        final createdAt = user['createdAt'] as Timestamp?;
        final formattedDate = createdAt != null
            ? DateFormat('MMM d, yyyy').format(createdAt.toDate())
            : 'Unknown date';

        return Card(
          margin: EdgeInsets.only(bottom: 16),
          elevation: 6,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: Colors.red.shade100,
              child: Text(
                (user['name'] != null && user['name'].isNotEmpty ? user['name'][0].toUpperCase() : '?'),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade700,
                ),
              ),
            ),
            title: Text(
              user['name'],
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('${dietPlans.length} diet plan(s) • Joined $formattedDate'),
            children: [
              ...dietPlans.asMap().entries.map((entry) {
                final planIndex = entry.key;
                final plan = entry.value as Map<String, dynamic>;
                final planText = plan['plan'] ?? 'No plan content';
                final planSnippet = planText.split('\n').first;

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.green.shade100,
                    child: Icon(Icons.restaurant_menu, color: Colors.green.shade700),
                  ),
                  title: Text('Diet Plan #${planIndex + 1}'),
                  subtitle: Text(
                    planSnippet,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.visibility, color: Colors.blue),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PlanDetailScreen(
                                plan: planText,
                                title: '${user['name']} - Diet Plan #${planIndex + 1}',
                              ),
                            ),
                          );
                        },
                        tooltip: 'View Plan',
                      ),
                      IconButton(
                        icon: Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteDietPlan(
                          user['uid'],
                          planIndex,
                          user['name'],
                        ),
                        tooltip: 'Delete Plan',
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
} 