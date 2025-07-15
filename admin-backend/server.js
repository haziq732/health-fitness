const express = require('express');
const cors = require('cors');
const admin = require('firebase-admin');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());

// Initialize Firebase Admin with service account
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'health-fitness-707c0' // <-- Your actual project ID
});

// Admin email for verification
const ADMIN_EMAIL = 'admin@gmail.com';

// Middleware to verify admin
const verifyAdmin = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({ error: 'No token provided' });
    }

    const token = authHeader.split('Bearer ')[1];
    const decodedToken = await admin.auth().verifyIdToken(token);

    if (decodedToken.email !== ADMIN_EMAIL) {
      return res.status(403).json({ error: 'Only admin can perform this action' });
    }

    req.user = decodedToken;
    next();
  } catch (error) {
    console.error('Error verifying admin:', error);
    res.status(401).json({ error: 'Invalid token' });
  }
};

// Health check endpoint
app.get('/', (req, res) => {
  res.json({ message: 'Admin Backend is running!' });
});

// Delete user endpoint
app.delete('/api/users/:uid', verifyAdmin, async (req, res) => {
  try {
    const { uid } = req.params;

    // Delete user from Firebase Auth
    await admin.auth().deleteUser(uid);

    console.log(`User ${uid} deleted successfully by admin`);
    res.json({ success: true, message: 'User deleted successfully' });
  } catch (error) {
    console.error('Error deleting user:', error);
    res.status(500).json({
      error: 'Failed to delete user',
      details: error.message
    });
  }
});

// Get user info endpoint (optional)
app.get('/api/users/:uid', verifyAdmin, async (req, res) => {
  try {
    const { uid } = req.params;
    const userRecord = await admin.auth().getUser(uid);
    res.json({ user: userRecord });
  } catch (error) {
    console.error('Error getting user:', error);
    res.status(500).json({
      error: 'Failed to get user',
      details: error.message
    });
  }
});

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
  console.log(`Admin email: ${ADMIN_EMAIL}`);
}); 