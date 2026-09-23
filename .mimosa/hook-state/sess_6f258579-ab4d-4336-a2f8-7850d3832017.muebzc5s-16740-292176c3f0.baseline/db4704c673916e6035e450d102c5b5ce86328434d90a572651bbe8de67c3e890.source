const https = require('https');

const AMAP_BASE_URL = 'https://restapi.amap.com';

function getAmapWeatherKey() {
  return process.env.AMAP_WEB_KEY || process.env.GAODE_API_KEY || process.env.AMAP_KEY;
}

function amapGet(path, params = {}) {
  const key = getAmapWeatherKey();
  if (!key) {
    const err = new Error('AMap Web key is not configured');
    err.status = 500;
    throw err;
  }

  const url = new URL(path, AMAP_BASE_URL);
  Object.entries({ ...params, key }).forEach(([name, value]) => {
    if (value !== undefined && value !== null && value !== '') {
      url.searchParams.set(name, value);
    }
  });

  return new Promise((resolve, reject) => {
    const req = https.get(url, (response) => {
      let raw = '';
      response.setEncoding('utf8');
      response.on('data', (chunk) => {
        raw += chunk;
      });
      response.on('end', () => {
        try {
          const parsed = JSON.parse(raw);
          if (parsed.status && parsed.status !== '1') {
            const err = new Error(parsed.info || '高德服务返回失败');
            err.status = 502;
            reject(err);
            return;
          }
          resolve(parsed);
        } catch (err) {
          err.status = 502;
          reject(err);
        }
      });
    });
    req.setTimeout(10000, () => {
      req.destroy(new Error('高德服务请求超时'));
    });
    req.on('error', (err) => {
      err.status = err.status || 502;
      reject(err);
    });
  });
}

async function getWeatherByCity(city) {
  const cityName = String(city || '').trim();
  if (!cityName) return null;

  const [liveData, forecastData] = await Promise.all([
    amapGet('/v3/weather/weatherInfo', {
      city: cityName,
      extensions: 'base',
    }),
    amapGet('/v3/weather/weatherInfo', {
      city: cityName,
      extensions: 'all',
    }),
  ]);

  const live = liveData?.lives?.[0] || {};
  const forecast = forecastData?.forecasts?.[0] || {};
  const today = forecast.casts?.[0] || {};

  const currentTemp = parseInt(live.temperature, 10);
  const highTemp = parseInt(today.daytemp, 10);
  const lowTemp = parseInt(today.nighttemp, 10);
  const humidity = parseInt(live.humidity, 10);

  return {
    city: live.city || forecast.city || cityName,
    date: live.reporttime?.slice(0, 10) || today.date || new Date().toISOString().slice(0, 10),
    temp: Number.isFinite(currentTemp) ? currentTemp : null,
    feelsLike: Number.isFinite(currentTemp) ? currentTemp : null,
    tempHigh: Number.isFinite(highTemp) ? highTemp : null,
    tempLow: Number.isFinite(lowTemp) ? lowTemp : null,
    weather: live.weather || today.dayweather || '未知',
    wind: [live.winddirection, live.windpower].filter(Boolean).join(' '),
    humidity: Number.isFinite(humidity) ? `${humidity}%` : '',
    forecast: Array.isArray(forecast.casts)
      ? forecast.casts.slice(1, 5).map((item) => ({
          date: item.date,
          dayWeather: item.dayweather,
          dayTemp: item.daytemp,
          nightTemp: item.nighttemp,
        }))
      : [],
  };
}

module.exports = {
  getWeatherByCity,
};
