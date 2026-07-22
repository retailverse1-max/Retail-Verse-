const mongoose = require('mongoose');
const { deleteProfile } = require('./controllers/authController');

async function run() {
  await mongoose.connect('mongodb://localhost:27017/retail_verse'); // Assuming local DB
  console.log("Connected");
  // Mock req, res
  // We need a test user.
}
run();
