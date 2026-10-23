# tasks.jsonl スキーマ定義

1行 = 1タスク。以下のフィールドを持つ。

## 版履歴
| 版 | 日付 | 変更 |
|---|---|---|
| v2 | 2026-08-24 | `origin_by` / `origin_type` / `origin_ref` を追加 |
| v1 | - | 初版 |

`origin_by` キーを持たないレコードは v1(旧スキーマ)。読み取り側は欠落を許容すること。

## フィールド一覧
| フィールド | 型 | 説明 |
|---|---|---|
| id | string | 一意識別子。{PROJECT}-{4桁連番}。再利用禁止 |
| project | string | プロジェクト名(またはサブプロジェクト名) |
| task | string | 何を実現するかの短い説明 |
| status | string | 未着手 / 進行中 / 検証待ち / 完了 / 保留 |
| progress | string | 状態だけでは分からない途中経過の補足 |
| depends_on | array[string] | 先に完了しているべきタスクIDのリスト(実行順序の制約) |
| done_when | string | 完了と判断する条件(完了条件) |
| evidence | object | 下記参照 |
| origin_by | string | 発生源のアクター。下記参照。新規レコードでは必須 |
| origin_type | string | 発生の種類。下記参照。新規レコードでは必須 |
| origin_ref | string \| null | 発生の文脈となったタスクID・成果物パス等。任意 |
| assignee | string | main / architect / ui-ux-designer / coder / reviewer / documenter |
| created_at | string | YYYY-MM-DD |
| updated_at | string | YYYY-MM-DD |

## evidence オブジェクトの中身
| フィールド | 説明 |
|---|---|
| unit_test | 該当するユニットテストのパスと結果 |
| integration_test | 該当する結合テストのパスと結果 |
| regression_test | CI実行結果へのリンクや結果 |
| manual_check | 実環境確認の記録(スクショパス、確認ログ等) |

未実施の項目は null のままにしておく。

## origin_by(誰が持ち込んだか)
| 値 | 意味 |
|---|---|
| user | ユーザー本人からの直接の依頼・指摘 |
| main | PM(メインエージェント)が統合・進捗確認の過程で起票 |
| architect | 設計・仕様策定の過程で発見 |
| ui-ux-designer | デザイン検討の過程で発見 |
| coder | 実装中に気づいた副次課題 |
| reviewer | コードレビュー、およびdocumenter成果物のファクトチェックでの指摘 |
| documenter | ドキュメント執筆中に発見した実装・仕様の矛盾 |
| security-review | security-review skill の実行による指摘 |
| external | CI失敗・依存更新・外部サービス仕様変更・エンドユーザー報告など |

`assignee` は「誰が作業するか」、`origin_by` は「誰が持ち込んだか」であり別概念。
`security-review` と `external` は origin_by 専用で、assignee には使わない。

## origin_type(どういう種類の発生か)
| 値 | 意味 |
|---|---|
| feature | 新機能・新規追加の要望 |
| improvement | 既存機能の改善・使い勝手向上 |
| bug | 期待動作を満たしていない不具合 |
| spec_gap | 仕様の欠落・曖昧さ・設計上の矛盾(実装は仕様どおりだが仕様が不十分) |
| doc | ドキュメントの誤り・不足 |
| security | 脆弱性・権限・秘匿情報の取り扱いに関する指摘 |
| refactor | 動作を変えない構造改善・技術的負債返済 |
| test | テスト不足・テスト自体の不備 |
| ops | 環境構築・CI/CD・依存更新・運用作業 |
| chore | 上記に当てはまらない雑務 |

判断に迷う場合の優先順位: security > bug > spec_gap > doc > test > その他。

## origin_ref
このタスクを生んだ文脈への参照。推奨形式:
- 他タスクID: `"IMP-0012"`
- 成果物パス: `"docs/guides/api-usage.md"`
- 外部参照: `"CI: run #1234"`

`depends_on`(先に完了すべきタスク)とは意味が異なる。
レビュー中に見つかったバグは、レビュー対象タスクに「依存」しないので
depends_on ではなく origin_ref に書く。

## ルール
- IDは既存のものを再利用しない。新しい問題・バグは既存タスクに追記せず新規タスクとして登録する
- statusを「完了」にできるのは、done_whenの条件を満たし、必要なevidenceが揃っている場合のみ
- origin_by / origin_type は起票時に必ず指定する。新規レコードで null は禁止
- origin_by / origin_type は原則として後から変更しない(出自は不変)。
  誤登録の訂正のみ task_update.sh の訂正オプションで行う
