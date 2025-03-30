const admin = require('firebase-admin');
const readline = require('readline');
const serviceAccount = require('../firebase-service-account.json');

// Initialize Firebase Admin
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

// Create readline interface for user input
const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout
});

// Prompt for email
rl.question('Enter email of the user to make superadmin: ', async (email) => {
  if (!email || email.trim() === '') {
    console.log('Email cannot be empty');
    rl.close();
    process.exit(1);
  }

  try {
    // Query Firestore to find the user with the given email
    const userQuery = await db.collection('agents')
      .where('email', '==', email.trim())
      .limit(1)
      .get();
    
    if (userQuery.empty) {
      console.log(`User with email ${email} not found`);
      rl.close();
      process.exit(1);
    }
    
    // Update the user document to set isSuperAdmin to true
    await db.collection('agents')
      .doc(userQuery.docs[0].id)
      .update({
        isSuperAdmin: true
      });
    
    console.log(`User ${email} has been set as superadmin`);
  } catch (e) {
    console.error('Failed to add superadmin:', e);
    process.exit(1);
  }
  
  rl.close();
  process.exit(0);
});