/**
 * Import function triggers from their respective submodules:
 *
 * const {onCall} = require("firebase-functions/v2/https");
 * const {onDocumentWritten} = require("firebase-functions/v2/firestore");
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

const functions = require("firebase-functions");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");

// Initialize Firebase Admin
admin.initializeApp();

// Create and deploy your first functions
// https://firebase.google.com/docs/functions/get-started

// exports.helloWorld = onRequest((request, response) => {
//   logger.info("Hello logs!", {structuredData: true});
//   response.send("Hello from Firebase!");
// });

// Function to delete user account from Firebase Auth (v1 syntax)
exports.deleteUserAccount = functions.https.onCall(async (data, context) => {
  // Only allow admin to delete users
  if (!context.auth || 
      context.auth.token.email !== "admin@gmail.com") {
    throw new functions.https.HttpsError(
        "permission-denied", 
        "Only admin can delete users."
    );
  }

  const uid = data.uid;

  try {
    await admin.auth().deleteUser(uid);
    logger.info(`User ${uid} deleted successfully by admin`);
    return {success: true};
  } catch (error) {
    logger.error(`Error deleting user ${uid}:`, error);
    throw new functions.https.HttpsError(
        "internal", 
        `Failed to delete user: ${error.message}`
    );
  }
});
