# sc2-stats-site

外服 SC2 天梯胜率快照报告. 数据由 `~/GolandProjects/sc2-crawler` 抓 sc2pulse 写入
ClickHouse Cloud, 再由 `~/.claude/skills/sc2-winrate/scripts/analyze_ch.py` 渲染为静态
HTML. 此 repo 只放渲染好的 `index.html`, 不含原始数据 / 凭据.

## 刷新报告

```bash
# 1. (可选) 先同步数据
#    在 Claude Code 里说 "更新 sc2 排位数据" 就行, 或手动:
cd ~/GolandProjects/sc2-crawler
./sc2-crawler --incremental --workers 20 --leagues DIAMOND,MASTER,GRANDMASTER

# 2. 重新生成
python3 ~/.claude/skills/sc2-winrate/scripts/analyze_ch.py \
    --since 2026-06-20 \
    --output ~/PycharmProjects/sc2-stats-site/index.html

# 3. 推上去, Cloudflare Pages 会自动重新部署
cd ~/PycharmProjects/sc2-stats-site
git add index.html
git commit -m "refresh report $(date +%Y-%m-%d)"
git push
```

## 部署

托管在 Cloudflare Pages. Build settings:
- Build command: 留空
- Build output directory: `/`
- Root directory: `/`
