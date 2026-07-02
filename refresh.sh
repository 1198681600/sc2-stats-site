#!/usr/bin/env bash
# 重新生成 SC2 胜率报告 HTML, 推到腾讯云 CloudBase + GitHub 留档.
#
# 数据采集靠服务器 cron 自动同步 (ubuntu@150.109.247.65, 每小时整点).
# 这个脚本只做"查 ClickHouse → 生成 HTML → 部署". 历史日期走本地按天缓存
# (~/.cache/sc2-winrate/days/), 常规刷新只重查最近 2 天; 数据指纹没变化时
# 直接跳过部署和 git push.
#
# 用法:
#   ./refresh.sh                     # 增量刷新, since 默认 2026-06-20
#   ./refresh.sh 2026-06-23          # 自定义 since
#   ./refresh.sh --full              # 兜底: 无视缓存全量重查 (旧数据修复 / 缓存疑似脏时救活)
#   ./refresh.sh 2026-06-23 --full
#
# 前置:
#   1. ~/GolandProjects/sc2-crawler/.env 配好 ClickHouse 凭据 (analyze_ch.py 也读这个)
#   2. tcb login 完成 (token 缓存在 ~/.cloudbase/, 偶尔会过期需要重 login)
#   3. git push 权限 OK

set -euo pipefail

SITE_DIR="$HOME/PycharmProjects/sc2-stats-site"
ANALYZE="$HOME/.claude/skills/sc2-winrate/scripts/analyze_ch.py"
TCB_ENV_ID="sc2-d5g8mj7ep2bbe48e0"
SINCE="2026-06-20"
FULL=0

for arg in "$@"; do
  case "$arg" in
    --full) FULL=1 ;;
    [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]) SINCE="$arg" ;;
    *) echo "未知参数: $arg (支持: YYYY-MM-DD / --full)" >&2; exit 2 ;;
  esac
done

step() { printf "\n\033[1;36m▸ %s\033[0m\n" "$1"; }
fp_of() { sed -n "s/.*data-fingerprint' content='\([0-9a-f]*\)'.*/\1/p" "$1" 2>/dev/null | head -1; }

cd "$SITE_DIR"
# tcb deploy 中途失败时也别残留 dist
trap 'rm -rf "$SITE_DIR/dist"' EXIT

OLD_FP="$(fp_of index.html || true)"

if [ "$FULL" = 1 ]; then
  step "1/3 查 ClickHouse 生成 HTML (since=$SINCE, --full 全量重查)"
  python3 "$ANALYZE" --since "$SINCE" --output "$SITE_DIR/index.html" --full
else
  step "1/3 查 ClickHouse 生成 HTML (since=$SINCE, 增量)"
  python3 "$ANALYZE" --since "$SINCE" --output "$SITE_DIR/index.html"
fi

NEW_FP="$(fp_of index.html || true)"
if [ "$FULL" = 0 ] && [ -n "$OLD_FP" ] && [ "$OLD_FP" = "$NEW_FP" ]; then
  echo "数据指纹未变 ($NEW_FP), 线上已是最新 — 跳过部署与 git push (--full 可强制部署)"
  git checkout -- index.html 2>/dev/null || true  # 回滚仅生成时间戳变化的重写
  exit 0
fi

step "2/3 推送到 CloudBase 静态托管"
# tcb hosting deploy 单文件模式偶发 BucketAlreadyExists; 走纯净 dist 目录稳定.
rm -rf dist && mkdir dist
cp index.html dist/
tcb hosting deploy ./dist / -e "$TCB_ENV_ID"

step "3/3 (顺便) 同步到 GitHub 留档"
if ! git diff --quiet index.html; then
  git add index.html
  git commit -m "refresh report $(date -u +'%Y-%m-%d %H:%M UTC')"
  git push origin main
else
  echo "  index.html 跟上次相同, 跳过 GitHub push"
fi

printf "\n\033[1;32m✓ 完成\033[0m\n"
echo "https://${TCB_ENV_ID}-1254308391.tcloudbaseapp.com/"
