require('dotenv').config(); 
const express = require('express');
const connectDB = require('./config/db'); 
const cors = require('cors');

const authRoute = require('./routes/auth');

const app = express();

connectDB();

app.use(express.json());
app.use(cors());         

app.use('/api/auth', authRoute);

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`🚀 Server running on port ${PORT}`));