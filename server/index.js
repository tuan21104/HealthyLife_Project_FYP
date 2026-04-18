require('dotenv').config(); 
const express = require('express');
const connectDB = require('./config/db'); 
const cors = require('cors');

const authRoute = require('./routes/auth');
const foodRoutes = require('./routes/food'); 
require('./jobs/waterReminder');

const app = express();

connectDB();

app.use(express.json());
app.use(cors());         

app.use('/api/auth', authRoute);
app.use('/api/foods', foodRoutes);
app.use('/api/diary', require('./routes/diary'));
app.use('/api/user-foods', require('./routes/userFood'));
app.use('/api/recipes', require('./routes/recipe'));
app.use('/api/upload', require('./routes/upload'));
app.use('/api/users', require('./routes/user'));
app.use('/api/user', require('./routes/user'));
app.use('/api/statistics', require('./routes/statistics'));
app.use('/api/shop', require('./routes/shop'));
app.use('/api/chat', require('./routes/chat'));
app.use('/api/expense', require('./routes/expense'));
app.use('/api/test', require('./routes/test'));

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`🚀 Server running on port ${PORT}`));