#!/usr/bin/env bash
# 刷新 SC2 胜率报告 -> 推到腾讯云 CloudBase + GitHub.
#
# 用法:
#   ./refresh.sh              # 默认 since=2026-06-20
#   ./refresh.sh 2026-06-23   # 自定义 since
#
# 前置:
#   1. ~/GolandProjects/sc2-crawler/.env 配好 ClickHouse 凭据
#   2. tcb login 完成 (一次性, token 缓存在本地)
#   3. git push 权限 OK

set -euo pipefail

CRAWLER_DIR="$HOME/GolandProjects/sc2-crawler"
SITE_DIR="$HOME/PycharmProjects/sc2-stats-site"
ANALYZE="$HOME/.claude/skills/sc2-winrate/scripts/analyze_ch.py"
TCB_ENV_ID="sc2-d5g8mj7ep2bbe48e0"
SINCE="${1:-2026-06-20}"

step() { printf "\n\033[1;36m▸ %s\033[0m\n" "$1"; }

step "1/3 同步增量数据 (sc2-crawler --incremental)"
cd "$CRAWLER_DIR"
./sc2-crawler --incremental --workers 20 --leagues DIAMOND,MASTER,GRANDMASTER

step "2/3 生成 HTML 报告 (since=$SINCE)"
python3 "$ANALYZE" --since "$SINCE" --output "$SITE_DIR/index.html"

step "3/3 推送到 CloudBase 静态托管"
cd "$SITE_DIR"
# tcb hosting deploy 单文件模式在 3.5.x 偶发 BucketAlreadyExists; 走纯净 dist 目录稳定.
rm -rf dist && mkdir dist
cp index.html dist/
tcb hosting deploy ./dist / -e "$TCB_ENV_ID"
rm -rf dist

step "(顺便) 同步到 GitHub 留档"
if ! git diff --quiet index.html; then
  git add index.html
  git commit -m "refresh report $(date -u +'%Y-%m-%d %H:%M UTC')"
  git push origin main
else
  echo "  index.html 跟上次相同, 跳过 GitHub push"
fi

printf "\n\033[1;32m✓ 完成\033[0m\n"
echo "访问 https://${TCB_ENV_ID//sc2-/}.tcloudbaseapp.com/ (CloudBase 静态托管默认域名)"
echo "或在腾讯云 CloudBase 控制台 -> 静态托管页面 查看具体域名"
