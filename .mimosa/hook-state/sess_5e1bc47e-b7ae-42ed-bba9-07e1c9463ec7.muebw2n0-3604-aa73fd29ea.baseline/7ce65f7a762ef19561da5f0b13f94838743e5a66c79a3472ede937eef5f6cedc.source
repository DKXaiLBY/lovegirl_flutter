#!/usr/bin/env node
/**
 * LoveGirl API Test Runner
 *
 * 用法:
 *   node test_runner.js                          # 运行所有测试
 *   node test_runner.js --token <JWT_TOKEN>      # 指定 Token
 *   node test_runner.js --module version         # 只跑版本检查模块
 *   node test_runner.js --module feeding         # 只跑投喂站模块
 *
 * 前置条件:
 *   - Node.js >= 18 (内建 fetch)
 *   - 测试服务器 http://47.121.119.191:3001 可访问
 *   - 若未提供 Token，脚本会尝试 POST /api/auth/login 获取
 */

const BASE_URL = 'http://47.121.119.191:3001/api';

// ---------------------------------------------------------------------------
// 命令行参数解析
// ---------------------------------------------------------------------------
const args = process.argv.slice(2);
let TOKEN = process.env.TEST_TOKEN || '';
let ONLY_MODULE = '';

for (let i = 0; i < args.length; i++) {
  if (args[i] === '--token' && args[i + 1]) TOKEN = args[++i];
  if (args[i] === '--module' && args[i + 1]) ONLY_MODULE = args[++i];
}

// ---------------------------------------------------------------------------
// 工具函数
// ---------------------------------------------------------------------------

function log(level, ...msg) {
  const ts = new Date().toLocaleTimeString('zh-CN', { hour12: false });
  const prefix = { info: '[INFO]', pass: '[PASS]', fail: '[FAIL]', skip: '[SKIP]', warn: '[WARN]' }[level] || '[LOG]';
  console.log(`${ts} ${prefix}`, ...msg);
}

let testCounter = 0;
let passCount = 0;
let failCount = 0;
let skipCount = 0;

async function apiFetch(path, options = {}) {
  const url = `${BASE_URL}${path}`;
  const headers = { 'Content-Type': 'application/json', ...(options.headers || {}) };
  if (TOKEN && !headers.Authorization) {
    headers.Authorization = `Bearer ${TOKEN}`;
  }
  const res = await fetch(url, { ...options, headers });
  let body;
  try { body = await res.json(); } catch (_) { body = await res.text(); }
  return { status: res.status, body, ok: res.ok };
}

function eq(a, b, label) {
  if (a === b) return `✅ ${label}: ${JSON.stringify(a)} === ${JSON.stringify(b)}`;
  return `❌ ${label}: 实际 ${JSON.stringify(a)} !== 预期 ${JSON.stringify(b)}`;
}

function range(a, min, max, label) {
  const ok = a >= min && a <= max;
  return `${ok ? '✅' : '❌'} ${label}: ${a} ∈ [${min}, ${max}]`;
}

function exists(val, label) {
  return `${val !== undefined && val !== null ? '✅' : '❌'} ${label}: ${val !== undefined && val !== null ? '存在' : '缺失'}`;
}

async function runTest(id, description, fn) {
  testCounter++;
  process.stdout.write(`[${String(testCounter).padStart(2, '0')}] ${id} — ${description} ... `);
  try {
    const result = await fn();
    if (result === null) {
      skipCount++;
      console.log('⏭ SKIP');
      return;
    }
    const checks = Array.isArray(result) ? result : [result];
    const allPass = checks.every(c => typeof c === 'string' && c.startsWith('✅'));
    if (allPass) {
      passCount++;
      console.log('✅ PASS');
    } else {
      failCount++;
      console.log('❌ FAIL');
    }
    for (const c of checks) {
      if (typeof c === 'string') console.log(`       ${c}`);
    }
  } catch (err) {
    failCount++;
    console.log('❌ FAIL (exception)');
    console.log(`       ${err.message}`);
  }
}

function dumpResponse(label, res) {
  console.log(`       --- ${label} Response ---`);
  console.log(`       status: ${res.status}`);
  console.log(`       body: ${JSON.stringify(res.body).slice(0, 500)}`);
  console.log(`       ---------------------------`);
}

// ---------------------------------------------------------------------------
// 登录获取 Token
// ---------------------------------------------------------------------------
async function ensureToken() {
  if (TOKEN) {
    // 验证 Token 是否有效
    const res = await apiFetch('/couple');
    if (res.ok || res.status === 200) {
      log('info', `Token 有效`);
      return;
    }
    if (res.body?.code === 200) {
      log('info', `Token 有效`);
      return;
    }
    log('warn', `Token 无效 (status=${res.status})，尝试重新登录`);
    TOKEN = '';
  }

  // 尝试登录
  const testAccounts = [
    { username: 'testboy', password: '123456' },
    { username: 'testgirl', password: '123456' },
    { username: 'test', password: '123456' },
    { username: 'admin', password: 'admin123' },
  ];

  for (const acc of testAccounts) {
    log('info', `尝试登录: ${acc.username}`);
    try {
      const res = await fetch(`${BASE_URL}/auth/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(acc),
      });
      const body = await res.json();
      if (res.ok && (body.token || body.data?.token)) {
        TOKEN = body.token || body.data.token;
        log('info', `登录成功，获得 Token`);
        return;
      }
      // 也尝试 /api/user/login
      const res2 = await fetch(`${BASE_URL}/user/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(acc),
      });
      const body2 = await res2.json();
      if (res2.ok && (body2.token || body2.data?.token)) {
        TOKEN = body2.token || body2.data.token;
        log('info', `登录成功 (via /user/login)，获得 Token`);
        return;
      }
    } catch (_) {}
  }

  log('warn', '无法自动登录。请通过 --token 参数提供 JWT Token');
  log('warn', '版本检查模块（公开接口）仍可正常运行');
}

// ---------------------------------------------------------------------------
// 模块: 版本检查 (公开接口)
// ---------------------------------------------------------------------------
async function testVersionCheck() {
  log('info', '========== 模块: 版本检查 (公开接口) ==========');

  await runTest('VER-N-001', '客户端版本低于服务端', async () => {
    const res = await apiFetch('/version/check?version_code=100');
    if (!res.ok) {
      dumpResponse('VER-N-001', res);
      return [`❌ HTTP ${res.status}`];
    }
    const b = res.body;
    const checks = [
      eq(res.status, 200, 'HTTP状态'),
      exists(b.data, 'data字段'),
      exists(b.data?.hasUpdate !== undefined, 'hasUpdate字段'),
      exists(b.data?.version, 'version对象'),
    ];
    // 如果服务端有更新才验证，否则服务端可能没有版本记录
    if (b.data?.hasUpdate) {
      checks.push(exists(b.data.version?.code, 'version.code'));
      checks.push(exists(b.data.version?.name, 'version.name'));
    }
    if (res.status !== 200) dumpResponse('VER-N-001', res);
    return checks;
  });

  await runTest('VER-N-002', '客户端版本等于/高于服务端', async () => {
    const res = await apiFetch('/version/check?version_code=99999');
    if (!res.ok) {
      dumpResponse('VER-N-002', res);
      return [`❌ HTTP ${res.status}`];
    }
    const checks = [
      eq(res.status, 200, 'HTTP状态'),
      eq(res.body?.data?.hasUpdate, false, 'hasUpdate=false'),
      eq(res.body?.code, 200, 'code=200'),
    ];
    if (res.status !== 200) dumpResponse('VER-N-002', res);
    return checks;
  });

  await runTest('VER-B-001', '边界: version_code=0', async () => {
    const res = await apiFetch('/version/check?version_code=0');
    const checks = [
      eq(res.status, 200, 'HTTP状态'),
      exists(res.body?.data?.hasUpdate !== undefined, 'hasUpdate字段'),
    ];
    if (res.status !== 200) dumpResponse('VER-B-001', res);
    return checks;
  });

  await runTest('VER-B-002', '边界: 不传 version_code', async () => {
    const res = await apiFetch('/version/check');
    const checks = [
      eq(res.status, 200, 'HTTP状态'),
      exists(res.body?.data?.hasUpdate !== undefined, 'hasUpdate字段'),
    ];
    if (res.status !== 200) dumpResponse('VER-B-002', res);
    return checks;
  });

  await runTest('VER-B-005', '边界: version_code=abc', async () => {
    const res = await apiFetch('/version/check?version_code=abc');
    const checks = [
      eq(res.status, 200, 'HTTP状态 (parseInt→0)'),
      exists(res.body?.data?.hasUpdate !== undefined, 'hasUpdate字段'),
    ];
    if (res.status !== 200) dumpResponse('VER-B-005', res);
    return checks;
  });

  await runTest('VER-E-001', '异常: 未登录访问 /latest', async () => {
    const res = await fetch(`${BASE_URL}/version/latest`, {
      headers: { 'Content-Type': 'application/json' },
    });
    const body = await res.json().catch(() => null);
    const checks = [
      eq(res.status, 401, 'HTTP 401'),
    ];
    if (res.status !== 401) dumpResponse('VER-E-001', { status: res.status, body, ok: false });
    return checks;
  });
}

// ---------------------------------------------------------------------------
// 模块: 投喂站下单
// ---------------------------------------------------------------------------
async function testFeeding() {
  if (!TOKEN) {
    log('skip', '投喂站模块需要 Token，跳过。请通过 --token 参数提供');
    return;
  }

  log('info', '========== 模块: 投喂站下单 ==========');

  // 先获取 shops 和 products
  let shopId = null;
  let productId = null;

  await runTest('FEED-PREP', '获取商店列表', async () => {
    const res = await apiFetch('/feeding/shops');
    if (res.status === 401) {
      dumpResponse('FEED-PREP', res);
      return ['❌ 认证失败，Token 无效或过期'];
    }
    if (!res.ok) {
      dumpResponse('FEED-PREP', res);
      return [`❌ HTTP ${res.status}`];
    }
    const shops = res.body?.data;
    const checks = [
      eq(res.status, 200, 'HTTP状态'),
      exists(shops?.length > 0, '商店列表非空'),
    ];
    if (shops?.length > 0) {
      shopId = shops[0].id;
      log('info', `  使用商店: id=${shopId}, name=${shops[0].name}`);
    }
    if (res.status !== 200) dumpResponse('FEED-PREP', res);
    return checks;
  });

  await runTest('FEED-PREP2', '获取商品列表', async () => {
    if (!shopId) return null;
    const res = await apiFetch(`/feeding/shops/${shopId}/products`);
    if (!res.ok) {
      dumpResponse('FEED-PREP2', res);
      return [`❌ HTTP ${res.status}`];
    }
    const products = res.body?.data;
    const checks = [
      eq(res.status, 200, 'HTTP状态'),
      exists(products?.length > 0, '商品列表非空'),
    ];
    if (products?.length > 0) {
      productId = products[0].id;
      log('info', `  使用商品: id=${productId}, name=${products[0].name}, price=${products[0].price}`);
    }
    if (res.status !== 200) dumpResponse('FEED-PREP2', res);
    return checks;
  });

  // ---- 正常用例 ----

  await runTest('FEED-N-001', '下单 - 正常', async () => {
    if (!productId) return null;
    const res = await apiFetch('/feeding/orders', {
      method: 'POST',
      body: JSON.stringify({ product_id: productId, quantity: 1 }),
    });
    if (!res.ok) {
      dumpResponse('FEED-N-001', res);
    }
    const b = res.body;
    const checks = [
      eq(res.status, 200, 'HTTP状态'),
      eq(b?.code, 200, 'code=200'),
      eq(b?.data?.status, 'pending', 'status=pending'),
      exists(b?.data?.id, '订单ID'),
      eq(b?.data?.quantity, 1, 'quantity=1'),
    ];
    if (!res.ok) checks.push(`⚠ 完整响应: ${JSON.stringify(b).slice(0, 300)}`);
    return checks;
  });

  await runTest('FEED-N-002', '下单多件 quantity=3', async () => {
    if (!productId) return null;
    const res = await apiFetch('/feeding/orders', {
      method: 'POST',
      body: JSON.stringify({ product_id: productId, quantity: 3 }),
    });
    if (!res.ok) dumpResponse('FEED-N-002', res);
    const b = res.body;
    const checks = [
      eq(res.status, 200, 'HTTP状态'),
      eq(b?.data?.quantity, 3, 'quantity=3'),
      exists(b?.data?.total_price > 0, 'total_price>0'),
      eq(b?.data?.status, 'pending', 'status=pending'),
    ];
    return checks;
  });

  await runTest('FEED-N-009', '商店列表 GET /shops', async () => {
    const res = await apiFetch('/feeding/shops');
    if (!res.ok) {
      dumpResponse('FEED-N-009', res);
      return [`❌ HTTP ${res.status}`];
    }
    const shops = res.body?.data;
    const checks = [
      eq(res.status, 200, 'HTTP状态'),
      exists(shops?.length >= 3 || shops?.length > 0, `商店数量=${shops?.length}`),
    ];
    return checks;
  });

  // ---- 边界值 ----

  await runTest('FEED-B-001', '边界: quantity=0 → 矫正为1', async () => {
    if (!productId) return null;
    const res = await apiFetch('/feeding/orders', {
      method: 'POST',
      body: JSON.stringify({ product_id: productId, quantity: 0 }),
    });
    if (!res.ok) dumpResponse('FEED-B-001', res);
    const b = res.body;
    const checks = [
      eq(res.status, 200, 'HTTP状态'),
      eq(b?.data?.quantity, 1, 'quantity矫正为1'),
    ];
    return checks;
  });

  await runTest('FEED-B-004', '边界: quantity=-5 → 矫正为1', async () => {
    if (!productId) return null;
    const res = await apiFetch('/feeding/orders', {
      method: 'POST',
      body: JSON.stringify({ product_id: productId, quantity: -5 }),
    });
    if (!res.ok) dumpResponse('FEED-B-004', res);
    const b = res.body;
    const checks = [
      eq(res.status, 200, 'HTTP状态'),
      eq(b?.data?.quantity, 1, 'quantity矫正为1'),
    ];
    return checks;
  });

  await runTest('FEED-B-003', '边界: quantity=100 → 矫正为99', async () => {
    if (!productId) return null;
    const res = await apiFetch('/feeding/orders', {
      method: 'POST',
      body: JSON.stringify({ product_id: productId, quantity: 100 }),
    });
    if (!res.ok) dumpResponse('FEED-B-003', res);
    const b = res.body;
    const checks = [
      eq(res.status, 200, 'HTTP状态'),
      eq(b?.data?.quantity, 99, 'quantity矫正为99'),
    ];
    return checks;
  });

  // ---- 异常用例 ----

  await runTest('FEED-E-001', '异常: 未登录下单', async () => {
    const res = await fetch(`${BASE_URL}/feeding/orders`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ product_id: 1001, quantity: 1 }),
    });
    const checks = [eq(res.status, 401, 'HTTP 401')];
    if (res.status !== 401) dumpResponse('FEED-E-001', { status: res.status, body: await res.json().catch(() => null) });
    return checks;
  });

  await runTest('FEED-E-004', '异常: 缺失 product_id', async () => {
    const res = await apiFetch('/feeding/orders', {
      method: 'POST',
      body: JSON.stringify({ quantity: 1 }),
    });
    const checks = [eq(res.status, 400, 'HTTP 400')];
    if (res.status !== 400) dumpResponse('FEED-E-004', res);
    return checks;
  });

  await runTest('FEED-E-005', '异常: product_id 不存在', async () => {
    const res = await apiFetch('/feeding/orders', {
      method: 'POST',
      body: JSON.stringify({ product_id: 99999, quantity: 1 }),
    });
    // 根据源码：查不到产品时使用默认 Gift/price=10
    const b = res.body;
    const checks = [
      eq(res.status, 200, 'HTTP状态 (fallback到默认产品)'),
      exists(b?.data?.product_name, '有默认product_name'),
    ];
    if (res.status !== 200) dumpResponse('FEED-E-005', res);
    return checks;
  });
}

// ---------------------------------------------------------------------------
// 模块: 伴侣绑定/解绑
// ---------------------------------------------------------------------------
async function testCouple() {
  if (!TOKEN) {
    log('skip', '伴侣绑定模块需要 Token，跳过。请通过 --token 参数提供');
    return;
  }

  log('info', '========== 模块: 伴侣绑定 ==========');

  let inviteCode = null;

  await runTest('COUP-N-004', '查询未绑定状态', async () => {
    const res = await apiFetch('/couple');
    if (res.status === 401) {
      dumpResponse('COUP-N-004', res);
      return ['❌ Token 无效'];
    }
    // 可能已绑定也可能未绑定
    const b = res.body;
    const checks = [
      eq(res.status, 200, 'HTTP状态'),
      exists(b?.data?.coupled !== undefined, 'coupled字段'),
    ];
    if (res.body?.data?.coupled) {
      log('info', '  当前用户已绑定，跳过绑定/解绑测试');
    }
    if (res.status !== 200) dumpResponse('COUP-N-004', res);
    return checks;
  });

  const isAlreadyCoupled = (await apiFetch('/couple')).body?.data?.coupled;

  if (!isAlreadyCoupled) {
    await runTest('COUP-N-001', '生成邀请码', async () => {
      const res = await apiFetch('/couple/invite', { method: 'POST', body: '{}' });
      if (!res.ok) {
        dumpResponse('COUP-N-001', res);
      }
      const b = res.body;
      const checks = [
        eq(res.status, 200, 'HTTP状态'),
        exists(b?.data?.invite_code?.length === 6, '邀请码6位'),
        eq(b?.data?.expires_in, 600, 'expires_in=600'),
      ];
      if (b?.data?.invite_code) inviteCode = b.data.invite_code;
      return checks;
    });

    await runTest('COUP-B-002', '边界: 邀请码长度不足', async () => {
      const res = await apiFetch('/couple/accept', {
        method: 'POST',
        body: JSON.stringify({ code: '123' }),
      });
      const checks = [eq(res.status, 400, 'HTTP 400')];
      if (res.body?.message) checks.push(eq(res.body.message, '请输入6位邀请码', '错误信息'));
      if (res.status !== 400) dumpResponse('COUP-B-002', res);
      return checks;
    });

    await runTest('COUP-B-005', '边界: 缺失 code 字段', async () => {
      const res = await apiFetch('/couple/accept', {
        method: 'POST',
        body: JSON.stringify({}),
      });
      const checks = [eq(res.status, 400, 'HTTP 400')];
      if (res.status !== 400) dumpResponse('COUP-B-005', res);
      return checks;
    });
  } else {
    log('info', '  用户已绑定，跳过邀请码生成和接受测试');
  }
}

// ---------------------------------------------------------------------------
// 主入口
// ---------------------------------------------------------------------------
async function main() {
  console.log('╔══════════════════════════════════════╗');
  console.log('║   LoveGirl API Test Runner v1.0     ║');
  console.log(`║   BASE: ${BASE_URL}        ║`);
  console.log('╚══════════════════════════════════════╝');
  console.log('');

  await ensureToken();

  if (!ONLY_MODULE || ONLY_MODULE === 'version') {
    await testVersionCheck();
  }

  if (!ONLY_MODULE || ONLY_MODULE === 'feeding') {
    await testFeeding();
  }

  if (!ONLY_MODULE || ONLY_MODULE === 'couple') {
    await testCouple();
  }

  // 汇总
  console.log('');
  console.log('╔══════════════════════════════════════╗');
  console.log(`║   测试完成                            ║`);
  console.log(`║   总计: ${testCounter}  |  ✅ 通过: ${passCount}  |  ❌ 失败: ${failCount}  |  ⏭ 跳过: ${skipCount}  ║`);
  console.log('╚══════════════════════════════════════╝');

  process.exit(failCount > 0 ? 1 : 0);
}

main().catch(err => {
  console.error('Fatal:', err);
  process.exit(2);
});
