// 天气路由 — 修复定位问题：不再默认广州
const express = require('express');
const router = express.Router();
const { authRequired } = require('../middleware/auth');
const { getWeatherByCity } = require('../utils/weather');
const pool = require('../config/database');

// GET /api/weather?city=深圳
router.get('/', async (req, res) => {
  try {
    const city = req.query.city;
    if (!city) {
      return res.status(400).json({ code: 400, message: '请提供城市名或使用 /api/weather/coords 接口' });
    }
    const weather = await getWeatherByCity(city);
    if (!weather) return res.status(500).json({ code: 500, message: '获取天气失败' });
    res.json({ code: 200, data: weather });
  } catch (err) {
    console.error('天气接口错误:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

// GET /api/weather/coords?lat=&lng=  — 经纬度获取精确天气
router.get('/coords', async (req, res) => {
  try {
    const { lat, lng } = req.query;
    if (!lat || !lng) return res.status(400).json({ code: 400, message: '请提供经纬度' });

    const axios = require('axios');
    const GAODE_KEY = process.env.GAODE_API_KEY || '';
    let fullAddress = '', city = '', adcode = '';

    // 1. 逆地理编码
    try {
      const geoRes = await axios.get('https://restapi.amap.com/v3/geocode/regeo', {
        params: { key: GAODE_KEY, location: `${lng},${lat}`, radius: 1000, extensions: 'base' },
        timeout: 8000
      });
      if (geoRes.data.status === '1' && geoRes.data.regeocode) {
        const addr = geoRes.data.regeocode.addressComponent || {};
        const province = addr.province || '';
        const cityName = (addr.city && addr.city.length > 0) ? addr.city : (addr.province || '');
        const district = addr.district || '';
        adcode = addr.adcode || '';
        const parts = [];
        if (province) parts.push(province);
        if (cityName && cityName !== province) parts.push(cityName);
        if (district) parts.push(district);
        fullAddress = parts.join('');
        city = cityName.replace(/市$/, '') || province.replace(/市$/, '');
      }
    } catch (geoErr) {
      console.error('[Weather] 逆地理编码失败:', geoErr.message);
    }

    if (!city && !adcode) {
      return res.status(500).json({ code: 500, message: '无法获取位置信息，请检查定位权限' });
    }

    // 2. 获取天气
    let weatherData = null;
    if (GAODE_KEY) {
      try {
        const weatherParam = adcode || city;
        const liveUrl = 'https://restapi.amap.com/v3/weather/weatherInfo';
        const [liveRes, forecastRes] = await Promise.all([
          axios.get(liveUrl, { params: { key: GAODE_KEY, city: weatherParam, extensions: 'base' }, timeout: 8000 }),
          axios.get(liveUrl, { params: { key: GAODE_KEY, city: weatherParam, extensions: 'all' }, timeout: 8000 })
        ]);
        const live = liveRes.data?.lives?.[0] || {};
        const forecast = forecastRes.data?.forecasts?.[0] || {};
        const todayCast = forecast.casts?.[0] || {};
        const currentTemp = parseInt(live.temperature) || parseInt(todayCast.daytemp) || null;
        const humidityVal = parseInt(live.humidity) || null;
        const casts = forecast.casts || [];

        weatherData = {
          city: fullAddress,
          date: todayCast.date || new Date().toISOString().split('T')[0],
          temp: currentTemp,
          tempHigh: parseInt(todayCast.daytemp) || null,
          tempLow: parseInt(todayCast.nighttemp) || null,
          weather: live.weather || todayCast.dayweather || '未知',
          wind: live.winddirection || todayCast.daywind || '',
          humidity: humidityVal != null ? `${humidityVal}%` : '',
          forecast: casts.slice(1, 5).map(c => ({
            date: c.date, dayWeather: c.dayweather, dayTemp: c.daytemp, nightTemp: c.nighttemp
          }))
        };
      } catch (wErr) {
        console.error('[Weather] 天气获取失败:', wErr.message);
      }
    }

    if (weatherData) return res.json({ code: 200, data: weatherData });
    res.json({ code: 200, data: { city: fullAddress || '未知', message: '天气数据暂不可用' } });
  } catch (err) {
    console.error('[Weather] /coords 错误:', err);
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

router.post('/reminder', authRequired, async (req, res) => {
  try {
    if (req.user.role !== 'boy') return res.status(403).json({ code: 403, message: '只有男友可以发送提醒' });
    const { content } = req.body;
    if (!content) return res.status(400).json({ code: 400, message: '请输入提醒内容' });
    const [girls] = await pool.query('SELECT id FROM users WHERE role = ?', ['girl']);
    if (girls.length === 0) return res.status(404).json({ code: 404, message: '未找到女友账号' });
    await pool.query('INSERT INTO push_messages (user_id, type, title, content) VALUES (?, ?, ?, ?)',
      [girls[0].id, 'custom', '天气提醒', content]);
    res.json({ code: 200, message: '提醒发送成功' });
  } catch (err) {
    res.status(500).json({ code: 500, message: '服务器错误' });
  }
});

module.exports = router;
