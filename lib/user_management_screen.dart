import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'services/admin_service.dart';
import 'plan_detail_screen.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});
  @override
  UserManagementScreenState createState() => UserManagementScreenState();
}

class UserManagementScreenState extends State<UserManagementScreen> {
  final AdminService _adminService = AdminService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _allUsers = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    loadUsers();
  }

  Future<void> loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final users = await _adminService.getAllUsers();
      setState(() {
        _allUsers = users;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('Failed to load users: $e');
    }
  }

  List<Map<String, dynamic>> get _filteredUsers {
    if (_searchQuery.isEmpty) return _allUsers;
    
    return _allUsers.where((user) {
      final name = user['name'].toString().toLowerCase();
      final email = user['email'].toString().toLowerCase();
      final query = _searchQuery.toLowerCase();
      
      return name.contains(query) || email.contains(query);
    }).toList();
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

  Future<void> _deleteUserAccount(String userId, String userName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete User Account'),
        content: Text(
          'Are you sure you want to delete the account for "$userName"?\n\n'
          'This action cannot be undone and will remove all user data including diet plans.',
        ),
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
        await _adminService.deleteUserAccount(userId);
        _showSuccessSnackBar('User account deleted successfully');
        loadUsers(); // Reload the user list
      } catch (e) {
        _showErrorSnackBar('Failed to delete user account: $e');
      }
    }
  }

  Future<void> _showUserDetails(Map<String, dynamic> user) async {
    try {
      final userDetails = await _adminService.getUserDetails(user['uid']);
      if (userDetails == null) {
        _showErrorSnackBar('Failed to load user details');
        return;
      }

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('User Details'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDetailRow('Name', userDetails['name']),
                _buildDetailRow('Email', userDetails['email']),
                _buildDetailRow('Age', userDetails['age']),
                _buildDetailRow('Gender', userDetails['gender']),
                _buildDetailRow('Weight', userDetails['weight']),
                _buildDetailRow('Height', userDetails['height']),
                _buildDetailRow('Activity Level', userDetails['activityLevel']),
                _buildDetailRow('Goal', userDetails['goal']),
                _buildDetailRow('Diet Plans', '${userDetails['dietPlans'].length} plans'),
                _buildDetailRow('Joined', _formatDate(userDetails['createdAt'])),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Close'),
            ),
            if (userDetails['dietPlans'].isNotEmpty)
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _showUserDietPlans(userDetails);
                },
                child: Text('View Diet Plans'),
              ),
          ],
        ),
      );
    } catch (e) {
      _showErrorSnackBar('Failed to load user details: $e');
    }
  }

  Widget _buildDetailRow(String label, dynamic value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.toString(),
              style: TextStyle(color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';
    if (timestamp is Timestamp) {
      return DateFormat('MMM d, yyyy').format(timestamp.toDate());
    }
    return 'Unknown';
  }

  void _showUserDietPlans(Map<String, dynamic> userDetails) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${userDetails['name']} - Diet Plans'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: ListView.builder(
            itemCount: userDetails['dietPlans'].length,
            itemBuilder: (context, index) {
              final plan = userDetails['dietPlans'][index];
              final planText = plan['plan'] ?? 'No plan content';
              final planSnippet = planText.split('\n').first;

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.green.shade100,
                  child: Icon(Icons.restaurant_menu, color: Colors.green.shade700),
                ),
                title: Text('Diet Plan #${index + 1}'),
                subtitle: Text(
                  planSnippet,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: IconButton(
                  icon: Icon(Icons.visibility, color: Colors.blue),
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PlanDetailScreen(
                          plan: planText,
                          title: '${userDetails['name']} - Diet Plan #${index + 1}',
                        ),
                      ),
                    );
                  },
                  tooltip: 'View Plan',
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
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
                  // Search Bar
                  _buildSearchBar(),
                  
                  // User Statistics
                  _buildUserStats(),
                  
                  // Users List
                  Expanded(
                    child: _filteredUsers.isEmpty
                        ? _buildEmptyState()
                        : _buildUsersList(),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: EdgeInsets.all(16),
      child: TextField(
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
        decoration: InputDecoration(
          hintText: 'Search users by name or email...',
          prefixIcon: Icon(Icons.search),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }

  Widget _buildUserStats() {
    final totalUsers = _allUsers.length;
    final usersWithPlans = _allUsers.where((user) => user['dietPlans'].isNotEmpty).length;
    final totalPlans = _allUsers.fold<int>(0, (sum, user) => sum + (user['dietPlans'] as List).length);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              'Total Users',
              totalUsers.toString(),
              Icons.people,
              Colors.blue,
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: _buildStatCard(
              'Active Users',
              usersWithPlans.toString(),
              Icons.restaurant_menu,
              Colors.green,
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: _buildStatCard(
              'Total Plans',
              totalPlans.toString(),
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
        padding: EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, size: 24, color: color),
            SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: TextStyle(
                fontSize: 10,
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
          Icon(Icons.people_outline, size: 80, color: Colors.red.shade300),
          SizedBox(height: 16),
          Text(
            _searchQuery.isEmpty ? 'No Users Found' : 'No Users Match Search',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.red.shade700,
            ),
          ),
          SizedBox(height: 8),
          Text(
            _searchQuery.isEmpty
                ? 'Users will appear here once they register.'
                : 'Try adjusting your search terms.',
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
      itemCount: _filteredUsers.length,
      itemBuilder: (context, index) {
        final user = _filteredUsers[index];
        final List<dynamic> dietPlans = user['dietPlans'];
        final createdAt = user['createdAt'] as Timestamp?;
        final formattedDate = createdAt != null
            ? DateFormat('MMM d, yyyy').format(createdAt.toDate())
            : 'Unknown date';

        return Card(
          margin: EdgeInsets.only(bottom: 12),
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
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
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user['email']),
                Text(
                  '${dietPlans.length} diet plan(s) • Joined $formattedDate',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.info_outline, color: Colors.blue),
                  onPressed: () => _showUserDetails(user),
                  tooltip: 'View Details',
                ),
                IconButton(
                  icon: Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _deleteUserAccount(user['uid'], user['name']),
                  tooltip: 'Delete Account',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
} 