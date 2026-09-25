#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
接口闸对账：App 接口清单 × 服务器路由清单

用法：
  python tools/api_audit.py --server-dir <服务器代码根目录> [--report docs/api-audit.md]

服务器代码根目录 = 含 app.js 与 routes/*.js 的目录（不含 node_modules）。
获取方式（在本机执行）：
  ssh root@47.121.119.191 "cd /opt/love-girl/love-girl-server && tar czf /tmp/lg-code.tgz --exclude='*.bak*' routes/*.js app.js middleware package.json"
  scp root@47.121.119.191:/tmp/lg-code.tgz %TEMP%\\lg-code.tgz && tar xzf %TEMP%\\lg-code.tgz -C %TEMP%\\lg-audit

对账规则：
  - App 端点：lib/**/*.dart 中 get/post/put/delete/patch/upload('<path>')，upload 视为 POST
  - 服务器路由：app.js 内联 app.verb + app.use 挂载前缀 × routes/*.js 中 router.verb
  - 路径段匹配：字面量相等，或服务器段为 :param / :param? / :param(regex) / *
  - 输出四类：App调用但服务器缺失 / 方法不匹配 / 服务器路由未被App调用 / 路由文件未挂载
退出码：发现"缺失"或"方法不匹配"时返回 1（可用作发布前闸门）
"""

import argparse
import re
import sys
from pathlib import Path

APP_ROOT = Path(__file__).resolve().parent.parent
VERB_RE = re.compile(
    r"\b(get|post|put|delete|patch|upload)\(\s*['\"](/api/[^'\"]*)['\"]")
# 服务器路由定义：router.get('/x') / router.route('/x').get(...) / app.get('/api/x')
ROUTE_VERB_RE = re.compile(
    r"\brouter\.(get|post|put|delete|patch|all|use)\(\s*['\"]([^'\"]*)['\"]")
ROUTE_CHAIN_RE = re.compile(
    r"\brouter\.route\(\s*['\"]([^'\"]+)['\"]\s*\)\s*\.(get|post|put|delete|patch|all)")
MOUNT_RE = re.compile(
    r"\bapp\.use\(\s*['\"]([^'\"]+)['\"]\s*,\s*require\(\s*['\"]([^'\"]+)['\"]")
INLINE_APP_RE = re.compile(
    r"\bapp\.(get|post|put|delete|patch)\(\s*['\"](/[^'\"]*)['\"]")
EXPRESS_ROUTER_RE = re.compile(r"express\.Router\(")

METHOD_MAP = {"upload": "POST"}
# 服务器侧对账时忽略的仅运维/开发用路由（App 不直连）
SERVER_ONLY_EXPECTED = {
    "/api/health", "/api/deploy/publish", "/api/deploy/status",
}


def norm_app_path(p):
    """App 侧路径规范化：$id 插值 → :param"""
    return re.sub(r"\$\w+", ":param", p)


def split_segs(p):
    return [s for s in p.strip().split("/") if s]


def seg_match(server_seg, app_seg, consumed):
    """单个路径段匹配。consumed 用于 :param? 可选段（回传是否按可选处理）"""
    if server_seg == app_seg:
        return True
    if server_seg == "*":
        return True
    m = re.match(r"^:(\w+)(\?)?(\(.*\))?$", server_seg)
    if m:
        if m.group(2):  # 可选参数段：空段视为匹配
            consumed.add(m.group(1))
        return True
    return False


def path_match(server_path, app_path):
    s_segs, a_segs = split_segs(server_path), split_segs(app_path)
    # 去掉可选段后比对两种形态（含/不含可选段）
    optional_idx = [i for i, s in enumerate(s_segs)
                    if re.match(r"^:\w+\?", s)]
    candidates = [s_segs]
    for i in optional_idx:
        candidates.append([s for j, s in enumerate(s_segs) if j != i])
    for cand in candidates:
        if len(cand) != len(a_segs):
            continue
        consumed = set()
        if all(seg_match(cs, a, consumed)
               for cs, a in zip(cand, a_segs)):
            return True
    return False


def scan_app_endpoints():
    """返回 {normalized_path: {"methods": set, "refs": [(file, line, raw_path)]}}"""
    eps = {}
    for dart in sorted(APP_ROOT.glob("lib/**/*.dart")):
        for lineno, line in enumerate(
                dart.read_text(encoding="utf-8", errors="replace").splitlines(), 1):
            for m in VERB_RE.finditer(line):
                verb, raw = m.group(1), m.group(2)
                path = norm_app_path(raw)
                ep = eps.setdefault(
                    path, {"methods": set(), "refs": []})
                ep["methods"].add(METHOD_MAP.get(verb, verb.upper()))
                ep["refs"].append(
                    (str(dart.relative_to(APP_ROOT)), lineno, verb, raw))
    return eps


def collect_server_routes(server_dir: Path):
    """返回 (routes, unmounted)
    routes: [{"method","path","file","line"}]
    unmounted: 含 express.Router() 但未被 app.js 挂载的文件"""
    app_js = server_dir / "app.js"
    text = app_js.read_text(encoding="utf-8", errors="replace")

    routes, mounts = [], []
    for lineno, line in enumerate(text.splitlines(), 1):
        for m in MOUNT_RE.finditer(line):
            mounts.append((m.group(1), m.group(2)))
        for m in INLINE_APP_RE.finditer(line):
            routes.append({"method": m.group(1).upper(),
                           "path": m.group(2), "file": "app.js", "line": lineno})

    mounted_files = set()
    for prefix, require_path in mounts:
        rf = (server_dir / require_path.lstrip("./")).with_suffix(".js")
        rf = rf.resolve()
        mounted_files.add(str(rf))
        if not rf.exists():
            print(f"[warn] 挂载目标不存在: {prefix} -> {require_path}",
                  file=sys.stderr)
            continue
        for lineno, line in enumerate(
                rf.read_text(encoding="utf-8", errors="replace").splitlines(), 1):
            for m in ROUTE_CHAIN_RE.finditer(line):
                routes.append({
                    "method": m.group(2).upper(),
                    "path": _join(prefix, m.group(1)),
                    "file": rf.name, "line": lineno})
                break  # 同一行不会叠两条链式定义
            for m in ROUTE_VERB_RE.finditer(line):
                verb, rpath = m.group(1), m.group(2)
                if verb == "use":
                    continue  # 中间件，不计入端点
                if verb == "all":
                    methods = {"GET", "POST", "PUT", "DELETE", "PATCH"}
                else:
                    methods = {verb.upper()}
                for meth in methods:
                    routes.append({
                        "method": meth,
                        "path": _join(prefix, rpath),
                        "file": rf.name, "line": lineno})

    unmounted = []
    for rf in sorted((server_dir / "routes").glob("*.js")):
        if str(rf.resolve()) not in mounted_files and EXPRESS_ROUTER_RE.search(
                rf.read_text(encoding="utf-8", errors="replace")):
            unmounted.append(rf.name)
    return routes, unmounted


def _join(prefix, rpath):
    if rpath.startswith("/api/"):
        return rpath
    p = prefix.rstrip("/")
    if rpath == "/" or rpath == "":
        return p or "/"
    return p + "/" + rpath.lstrip("/")


def find_server_match(app_path, srv_paths):
    """App 路径 → 最匹配的服务器路由。精确匹配优先，其次字面量段多者优先。"""
    if app_path in srv_paths:
        return app_path
    best, best_key = None, None
    for sp in srv_paths:
        if path_match(sp, app_path):
            segs = split_segs(sp)
            literal = sum(1 for s in segs
                          if not s.startswith(":") and s != "*")
            key = (-literal, len(segs), sp)
            if best_key is None or key < best_key:
                best, best_key = sp, key
    return best


def main():
    ap = argparse.ArgumentParser(description="App×服务器 接口对账")
    ap.add_argument("--server-dir", required=True)
    ap.add_argument("--report")
    args = ap.parse_args()

    server_dir = Path(args.server_dir)
    app_eps = scan_app_endpoints()
    server_routes, unmounted = collect_server_routes(server_dir)

    # 服务器路由索引：path -> methods
    srv = {}
    for r in server_routes:
        srv.setdefault(r["path"], set()).add(r["method"])

    missing, method_mismatch, unused = [], [], []
    for apath in sorted(app_eps):
        need = app_eps[apath]["methods"]
        hit = find_server_match(apath, srv)
        if hit is None:
            missing.append(apath)
        elif not need <= srv[hit]:
            method_mismatch.append((apath, sorted(need), sorted(srv[hit]), hit))

    called_paths = {hit for hit in
                    (find_server_match(a, srv) for a in app_eps) if hit}
    for spath in sorted(srv):
        if spath not in called_paths:
            unused.append(spath)

    n_app = len(app_eps)
    n_srv = len(srv)
    print(f"App 端点 {n_app} 个 × 服务器路由 {n_srv} 条")
    print(f"缺失 {len(missing)} / 方法不匹配 {len(method_mismatch)} / "
          f"服务器未用 {len(unused)} / 未挂载文件 {len(unmounted)}")

    lines = ["# 接口闸对账报告", "",
             f"- App 端点：{n_app}（lib/ 全量 `/api/` 调用）",
             f"- 服务器路由：{n_srv}（app.js 内联 + 挂载路由）", ""]

    if missing:
        lines += ["## ❌ App 调用但服务器缺失", ""]
        for p in missing:
            refs = "; ".join(f"{f}:{l} ({v}('{r}'))"
                             for f, l, v, r in app_eps[p]["refs"])
            lines.append(f"- `{p}` ← {refs}")
        lines.append("")
    if method_mismatch:
        lines += ["## ❌ 方法不匹配", ""]
        for p, need, have, hit in method_mismatch:
            lines.append(f"- `{p}` App={need} 服务器[{hit}]={have}")
        lines.append("")
    if unused:
        lines += ["## ℹ️ 服务器路由未被 App 调用（运维/开发用为正常）", ""]
        for p in unused:
            tag = "（预期内）" if p in SERVER_ONLY_EXPECTED else ""
            lines.append(f"- `{p}`{tag}")
        lines.append("")
    if unmounted:
        lines += ["## ⚠️ 含 Router 但未在 app.js 挂载的文件", ""]
        for f in unmounted:
            lines.append(f"- routes/{f}")
        lines.append("")

    lines += ["## App 全量接口清单", "",
              "| # | 方法 | 路径 | 调用位置 |", "|---|---|---|---|"]
    for i, p in enumerate(sorted(app_eps), 1):
        refs = "<br>".join(f"{f}:{l} `{v}`"
                           for f, l, v, _ in app_eps[p]["refs"])
        lines.append(f"| {i} | {'/'.join(sorted(app_eps[p]['methods']))} "
                     f"| `{p}` | {refs} |")
    lines += ["", "## 服务器全量路由清单", "",
              "| # | 方法 | 路径 | 定义位置 |", "|---|---|---|---|"]
    seen = set()
    idx = 0
    for r in sorted(server_routes, key=lambda x: (x["path"], x["method"])):
        key = (r["path"], r["method"])
        if key in seen:
            continue
        seen.add(key)
        idx += 1
        lines.append(f"| {idx} | {r['method']} | `{r['path']}` "
                     f"| {r['file']}:{r['line']} |")
    report = "\n".join(lines) + "\n"

    if args.report:
        Path(args.report).write_text(report, encoding="utf-8")
        print(f"报告已写入 {args.report}")
    else:
        print(report)

    sys.exit(1 if (missing or method_mismatch) else 0)


if __name__ == "__main__":
    main()
