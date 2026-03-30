require('dotenv').config(); 
const express = require('express');
const connectDB = require('./config/db'); 
const cors = require('cors');

const authRoute = require('./routes/auth');
const foodRoutes = require('./routes/food'); 

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

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`🚀 Server running on port ${PORT}`));