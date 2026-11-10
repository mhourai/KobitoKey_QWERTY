#!/bin/bash
# tasks.jsonl の既存タスクを1件更新する(スキーマv2・名前付きオプション形式・部分更新)
#
# 使い方:
#   task_update.sh --id ID --file PATH [--status S] [--progress "..."] \
#                  [--assignee A] [--origin-by X] [--origin-type Y] [--origin-ref REF]
set -euo pipefail

ORIGIN_BY_VALUES="user main architect ui-ux-designer coder reviewer documenter security-review external"
ORIGIN_TYPE_VALUES="feature improvement bug spec_gap doc security refactor test ops chore"
ASSIGNEE_VALUES="main architect ui-ux-designer coder reviewer documenter"

usage() {
  cat <<'EOF'
使い方: task_update.sh --id ID --file PATH [--status S] [--progress "..."] \
                       [--assignee A] [--origin-by X] [--origin-type Y] [--origin-ref REF]

  origin-by:   user|main|architect|ui-ux-designer|coder|reviewer|documenter|security-review|external
  origin-type: feature|improvement|bug|spec_gap|doc|security|refactor|test|ops|chore
  assignee:    main|architect|ui-ux-designer|coder|reviewer|documenter

明示的に渡したフィールドのみ更新される(渡さないフィールドは変更されない)。
--origin-* を渡すと警告が表示される(発生源は原則として後から変更しない)。
EOF
}

# 旧位置引数形式(第1引数が "-" で始まらない)を明示的に拒否する
if [ "$#" -gt 0 ]; then
  case "$1" in
    -*) ;;
    *)
      echo "エラー: task_update.sh は名前付きオプション形式に変更されました(スキーマv2)。" >&2
      usage >&2
      exit 1
      ;;
  esac
fi

ID=""
FILE=""
STATUS_SET=0; STATUS=""
PROGRESS_SET=0; PROGRESS=""
ASSIGNEE_SET=0; ASSIGNEE=""
ORIGIN_BY_SET=0; ORIGIN_BY=""
ORIGIN_TYPE_SET=0; ORIGIN_TYPE=""
ORIGIN_REF_SET=0; ORIGIN_REF=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --id) ID="${2:-}"; shift 2 ;;
    --file) FILE="${2:-}"; shift 2 ;;
    --status) STATUS="${2:-}"; STATUS_SET=1; shift 2 ;;
    --progress) PROGRESS="${2:-}"; PROGRESS_SET=1; shift 2 ;;
    --assignee) ASSIGNEE="${2:-}"; ASSIGNEE_SET=1; shift 2 ;;
    --origin-by) ORIGIN_BY="${2:-}"; ORIGIN_BY_SET=1; shift 2 ;;
    --origin-type) ORIGIN_TYPE="${2:-}"; ORIGIN_TYPE_SET=1; shift 2 ;;
    --origin-ref) ORIGIN_REF="${2:-}"; ORIGIN_REF_SET=1; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *)
      echo "エラー: 不明なオプションです: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

MISSING=""
[ -z "$ID" ] && MISSING="$MISSING --id"
[ -z "$FILE" ] && MISSING="$MISSING --file"
if [ -n "$MISSING" ]; then
  echo "エラー: 必須オプションが不足しています:$MISSING" >&2
  usage >&2
  exit 1
fi

if [ "$STATUS_SET" -eq 0 ] && [ "$PROGRESS_SET" -eq 0 ] && [ "$ASSIGNEE_SET" -eq 0 ] \
   && [ "$ORIGIN_BY_SET" -eq 0 ] && [ "$ORIGIN_TYPE_SET" -eq 0 ] && [ "$ORIGIN_REF_SET" -eq 0 ]; then
  echo "エラー: 更新するフィールドが指定されていません(--status / --progress / --assignee / --origin-* のいずれかを指定してください)。" >&2
  exit 1
fi

is_in_list() {
  local value="$1" list="$2" item
  for item in $list; do
    if [ "$item" = "$value" ]; then
      return 0
    fi
  done
  return 1
}

if [ "$ASSIGNEE_SET" -eq 1 ] && ! is_in_list "$ASSIGNEE" "$ASSIGNEE_VALUES"; then
  echo "エラー: --assignee の値が不正です: $ASSIGNEE" >&2
  echo "  候補: ${ASSIGNEE_VALUES// /|}" >&2
  exit 1
fi

if [ "$ORIGIN_BY_SET" -eq 1 ] && ! is_in_list "$ORIGIN_BY" "$ORIGIN_BY_VALUES"; then
  echo "エラー: --origin-by の値が不正です: $ORIGIN_BY" >&2
  echo "  候補: ${ORIGIN_BY_VALUES// /|}" >&2
  exit 1
fi

if [ "$ORIGIN_TYPE_SET" -eq 1 ] && ! is_in_list "$ORIGIN_TYPE" "$ORIGIN_TYPE_VALUES"; then
  echo "エラー: --origin-type の値が不正です: $ORIGIN_TYPE" >&2
  echo "  候補: ${ORIGIN_TYPE_VALUES// /|}" >&2
  exit 1
fi

if [ ! -f "$FILE" ]; then
  echo "エラー: $FILE が見つかりません。" >&2
  exit 1
fi

if ! jq -e --arg id "$ID" -s 'any(.[]; .id == $id)' "$FILE" >/dev/null 2>&1; then
  echo "エラー: ID $ID は $FILE に見つかりません。" >&2
  exit 1
fi

TODAY=$(date +%Y-%m-%d)
TMP=$(mktemp)

jq -c \
  --arg id "$ID" --arg today "$TODAY" \
  --argjson status_set "$STATUS_SET" --arg status "$STATUS" \
  --argjson progress_set "$PROGRESS_SET" --arg progress "$PROGRESS" \
  --argjson assignee_set "$ASSIGNEE_SET" --arg assignee "$ASSIGNEE" \
  --argjson origin_by_set "$ORIGIN_BY_SET" --arg origin_by "$ORIGIN_BY" \
  --argjson origin_type_set "$ORIGIN_TYPE_SET" --arg origin_type "$ORIGIN_TYPE" \
  --argjson origin_ref_set "$ORIGIN_REF_SET" --arg origin_ref "$ORIGIN_REF" \
  '
  if .id == $id then
    (if $status_set == 1 then .status = $status else . end)
    | (if $progress_set == 1 then .progress = $progress else . end)
    | (if $assignee_set == 1 then .assignee = $assignee else . end)
    | (if $origin_by_set == 1 then .origin_by = $origin_by else . end)
    | (if $origin_type_set == 1 then .origin_type = $origin_type else . end)
    | (if $origin_ref_set == 1 then .origin_ref = (if $origin_ref == "" then null else $origin_ref end) else . end)
    | .updated_at = $today
  else . end
  ' "$FILE" > "$TMP" && mv "$TMP" "$FILE"

if [ "$ORIGIN_BY_SET" -eq 1 ] || [ "$ORIGIN_TYPE_SET" -eq 1 ] || [ "$ORIGIN_REF_SET" -eq 1 ]; then
  echo "警告: 発生源(origin)を訂正しました。通常運用では変更不要です。"
fi

echo "更新しました: $ID -> $FILE"
