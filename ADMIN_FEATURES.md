# Admin User Management Features

## Overview
The admin account now has comprehensive user management capabilities to view, manage, and delete registered user accounts.

## Admin Access
- **Admin Email**: `admin@gmail.com` (configurable in `lib/services/admin_service.dart`)
- **Access Method**: Login with the admin email to automatically get admin privileges

## Features Implemented

### 1. User Management Screen
- **Location**: `lib/user_management_screen.dart`
- **Access**: Available as a tab in the Admin Dashboard
- **Features**:
  - View all registered users (including those without diet plans)
  - Search users by name or email
  - View detailed user information
  - Delete user accounts
  - View user statistics

### 2. Enhanced Admin Service
- **Location**: `lib/services/admin_service.dart`
- **New Methods**:
  - `getAllUsers()`: Get all registered users (excluding admin)
  - `getUserDetails(String userId)`: Get detailed user information
  - `deleteUserAccount(String userId)`: Delete user account and data

### 3. User Information Display
The admin can view the following user details:
- **Basic Info**: Name, Email, Join Date
- **Profile Data**: Age, Gender, Weight, Height, Activity Level, Goal
- **Diet Plans**: Number of plans and ability to view them
- **Account Status**: Active/Inactive based on diet plan creation

### 4. User Account Management
- **View User Details**: Click info icon to see complete user profile
- **Delete User Account**: Click delete icon to remove user and all associated data
- **Safety Measures**: 
  - Confirmation dialog before deletion
  - Cannot delete admin account
  - Error handling for failed operations

### 5. Search and Filter
- **Search Bar**: Filter users by name or email
- **Real-time Search**: Results update as you type
- **Statistics**: Shows total users, active users, and total diet plans

## Navigation Structure

### Admin Dashboard Tabs
1. **Diet Plans Tab** (Original functionality)
   - View users with diet plans
   - Manage individual diet plans
   - Delete specific diet plans

2. **User Management Tab** (New functionality)
   - View all registered users
   - Search and filter users
   - Manage user accounts
   - View user statistics

## Security Features

### Admin Protection
- Admin account cannot be deleted
- Admin email is configurable in the service
- Admin privileges are checked on each operation

### User Data Protection
- Confirmation dialogs for destructive actions
- Error handling for all operations
- Graceful handling of missing data

## Usage Instructions

### For Admins:
1. **Login**: Use admin email (`admin@gmail.com`)
2. **Access Dashboard**: Admin dashboard will be available
3. **Navigate**: Use the tab bar to switch between Diet Plans and User Management
4. **Manage Users**: 
   - Search for specific users
   - View detailed information
   - Delete accounts when necessary

### User Management Operations:
1. **View User Details**: Click the info icon next to any user
2. **Delete User**: Click the delete icon and confirm
3. **Search Users**: Use the search bar at the top
4. **View Statistics**: See overview cards at the top

## Technical Implementation

### Files Modified/Created:
- `lib/services/admin_service.dart` - Enhanced with new methods
- `lib/admin_screen.dart` - Added tab navigation
- `lib/user_management_screen.dart` - New user management interface

### Database Operations:
- **Read**: Fetch all users, user details, statistics
- **Delete**: Remove user documents from Firestore
- **Filter**: Client-side filtering for search functionality

### UI Components:
- **TabBar**: Navigation between diet plans and user management
- **SearchBar**: Real-time user filtering
- **User Cards**: Display user information with action buttons
- **Detail Dialogs**: Modal windows for detailed user information
- **Confirmation Dialogs**: Safety confirmations for deletions

## Future Enhancements
- Bulk user operations
- User activity tracking
- Export user data
- User role management
- Advanced filtering options
- User communication features

## Notes
- User deletion only removes Firestore data (not Firebase Auth)
- Admin account is protected from deletion
- All operations include proper error handling
- UI is responsive and follows Material Design guidelines 