const express = require('express');
const cors = require('cors');
const compression = require('compression');
require('dotenv').config();

const app = express();

// Middleware
app.use(cors());
app.use(compression());
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

// Health check
app.get('/api/health', (req, res) => res.json({ code: 200, message: 'OK' }));

// Routes
app.use('/api/auth', require('./routes/auth'));
app.use('/api/user', require('./routes/user'));
app.use('/api/travel', require('./routes/travel'));
app.use('/api/period', require('./routes/period'));
app.use('/api/calorie', require('./routes/calorie'));
app.use('/api/todo', require('./routes/todo'));
app.use('/api/finance', require('./routes/finance'));
app.use('/api/course', require('./routes/course'));
app.use('/api/photo', require('./routes/photo'));
app.use('/api/mood', require('./routes/mood'));
app.use('/api/chat', require('./routes/chat'));
app.use('/api/timeline', require('./routes/timeline'));
app.use('/api/feeding', require('./routes/feeding'));
app.use('/api/weather', require('./routes/weather'));
app.use('/api/version', require('./routes/version'));
app.use('/api/search', require('./routes/search'));
app.use('/api/sync', require('./routes/sync'));
app.use('/api/activity', require('./routes/activity'));
app.use('/api/admin', require('./routes/admin'));
app.use('/api/aliases', require('./routes/aliases'));
app.use('/api/anniversary', require('./routes/anniversary'));
app.use('/api/daily', require('./routes/daily'));
app.use('/api/exam', require('./routes/exam'));
app.use('/api/privacy', require('./routes/privacy'));

// Error handling
app.use((err, req, res, next) => {
  console.error('Server error:', err);
  res.status(500).json({ code: 500, message: '服务器内部错误' });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log('LoveGirl server running on port', PORT);
});
