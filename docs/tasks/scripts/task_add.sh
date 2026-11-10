#!/bin/bash
# tasks.jsonl に新規タスクを1件追記する(スキーマv2・名前付きオプション形式)
#
# 使い方:
#   task_add.sh --id ID --project P --task "..." --done-when "..." \
#               --origin-by X --origin-type Y --assignee A --file PATH \
#               [--depends-on "ID1,ID2"] [--origin-ref REF]
set -euo pipefail

ORIGIN_BY_VALUES="user main architect ui-ux-designer coder reviewer documenter security-review external"
ORIGIN_TYPE_VALUES="feature improvement bug spec_gap doc security refactor test ops chore"
ASSIGNEE_VALUES="main architect ui-ux-designer coder reviewer documenter"

usage() {
  cat <<'EOF'
使い方: task_add.sh --id ID --project P --task "..." --done-when "..." \
                    --origin-by X --origin-type Y --assignee A --file PATH \
                    [--depends-on "ID1,ID2"] [--origin-ref REF]

  origin-by:   user|main|architect|ui-ux-designer|coder|reviewer|documenter|security-review|external
  origin-type: feature|improvement|bug|spec_gap|doc|security|refactor|test|ops|chore
  assignee:    main|architect|ui-ux-designer|coder|reviewer|documenter
EOF
}

# 旧位置引数形式(第1引数が "-" で始まらない)を明示的に拒否する
if [ "$#" -gt 0 ]; then
  case "$1" in
    -*) ;;
    *)
      echo "エラー: task_add.sh は名前付きオプション形式に変更されました(スキーマv2)。" >&2
      usage >&2
      exit 1
      ;;
  esac
fi

ID=""
PROJECT=""
TASK=""
DEPENDS=""
DONE_WHEN=""
ORIGIN_BY=""
ORIGIN_TYPE=""
ORIGIN_REF=""
ASSIGNEE=""
FILE=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --id) ID="${2:-}"; shift 2 ;;
    --project) PROJECT="${2:-}"; shift 2 ;;
    --task) TASK="${2:-}"; shift 2 ;;
    --depends-on) DEPENDS="${2:-}"; shift 2 ;;
    --done-when) DONE_WHEN="${2:-}"; shift 2 ;;
    --origin-by) ORIGIN_BY="${2:-}"; shift 2 ;;
    --origin-type) ORIGIN_TYPE="${2:-}"; shift 2 ;;
    --origin-ref) ORIGIN_REF="${2:-}"; shift 2 ;;
    --assignee) ASSIGNEE="${2:-}"; shift 2 ;;
    --file) FILE="${2:-}"; shift 2 ;;
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
[ -z "$PROJECT" ] && MISSING="$MISSING --project"
[ -z "$TASK" ] && MISSING="$MISSING --task"
[ -z "$DONE_WHEN" ] && MISSING="$MISSING --done-when"
[ -z "$ORIGIN_BY" ] && MISSING="$MISSING --origin-by"
[ -z "$ORIGIN_TYPE" ] && MISSING="$MISSING --origin-type"
[ -z "$ASSIGNEE" ] && MISSING="$MISSING --assignee"
[ -z "$FILE" ] && MISSING="$MISSING --file"

if [ -n "$MISSING" ]; then
  echo "エラー: 必須オプションが不足しています:$MISSING" >&2
  usage >&2
  exit 1
fi

is_in_list() {
  # $1 = 値, $2 = スペース区切りの候補一覧
  local value="$1" list="$2" item
  for item in $list; do
    if [ "$item" = "$value" ]; then
      return 0
    fi
  done
  return 1
}

if ! is_in_list "$ORIGIN_BY" "$ORIGIN_BY_VALUES"; then
  echo "エラー: --origin-by の値が不正です: $ORIGIN_BY" >&2
  echo "  候補: ${ORIGIN_BY_VALUES// /|}" >&2
  exit 1
fi

if ! is_in_list "$ORIGIN_TYPE" "$ORIGIN_TYPE_VALUES"; then
  echo "エラー: --origin-type の値が不正です: $ORIGIN_TYPE" >&2
  echo "  候補: ${ORIGIN_TYPE_VALUES// /|}" >&2
  exit 1
fi

if ! is_in_list "$ASSIGNEE" "$ASSIGNEE_VALUES"; then
  echo "エラー: --assignee の値が不正です: $ASSIGNEE" >&2
  echo "  候補: ${ASSIGNEE_VALUES// /|}" >&2
  exit 1
fi

if [ ! -f "$FILE" ]; then
  echo "エラー: $FILE が見つかりません。STRUCTURE.md を確認し、正しい配置先か確認してください。" >&2
  exit 1
fi

if jq -e --arg id "$ID" -s 'any(.[]; .id == $id)' "$FILE" >/dev/null 2>&1; then
  echo "エラー: ID $ID は既に存在します。新しいIDを使ってください。" >&2
  exit 1
fi

TODAY=$(date +%Y-%m-%d)
DEPENDS_JSON=$(echo "$DEPENDS" | jq -R 'split(",") | map(select(length > 0))')

ORIGIN_REF_JSON="null"
if [ -n "$ORIGIN_REF" ]; then
  ORIGIN_REF_JSON=$(jq -n --arg v "$ORIGIN_REF" '$v')
fi

jq -nc \
  --arg id "$ID" --arg project "$PROJECT" --arg task "$TASK" \
  --argjson depends "$DEPENDS_JSON" --arg done_when "$DONE_WHEN" \
  --arg origin_by "$ORIGIN_BY" --arg origin_type "$ORIGIN_TYPE" \
  --argjson origin_ref "$ORIGIN_REF_JSON" \
  --arg assignee "$ASSIGNEE" --arg today "$TODAY" \
  '{id:$id, project:$project, task:$task, status:"未着手", progress:"",
    depends_on:$depends, done_when:$done_when,
    evidence:{unit_test:null,integration_test:null,regression_test:null,manual_check:null},
    origin_by:$origin_by, origin_type:$origin_type, origin_ref:$origin_ref,
    assignee:$assignee, created_at:$today, updated_at:$today}' >> "$FILE"

echo "追加しました: $ID -> $FILE"
