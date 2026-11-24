function studyProvider(task) {
  const prefix = `LOVEGIRL_STUDY_${task}_`;
  const baseUrl = process.env[prefix + 'BASE_URL']?.trim();
  const apiKey = process.env[prefix + 'API_KEY']?.trim();
  const model = process.env[prefix + 'MODEL']?.trim();
  if (!baseUrl || !apiKey || !model) {
    const legacy = process.env.LOVEGIRL_STUDY_DASHSCOPE_API_KEY?.trim();
    if (task !== 'TEXT' || !legacy || baseUrl || apiKey || model) return null;
    return {
      url: 'https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions',
      apiKey: legacy,
      model: 'qwen-plus',
      label: '阿里云百炼',
      options: { enable_thinking: false }
    };
  }
  try {
    const url = new URL(baseUrl);
    if (url.protocol !== 'https:' || url.username || url.password || url.hash || url.search) return null;
    const path = url.pathname.replace(/\/+$/, '');
    url.pathname = path.endsWith('/chat/completions') ? path : path + '/chat/completions';
    return {
      url: url.href,
      apiKey,
      model,
      label: process.env[prefix + 'LABEL']?.trim().slice(0, 60) || url.hostname,
      options: url.hostname === 'api.deepseek.com'
        ? { thinking: { type: 'disabled' } }
        : url.hostname === 'dashscope.aliyuncs.com' ? { enable_thinking: false } : {}
    };
  } catch (_) {
    return null;
  }
}

module.exports = { studyProvider };
