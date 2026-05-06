# gold-low-lot-auto-ea

MT4（MQL4）用のXAUUSD低ロット検証向け自動売買EAです。

このEAは**利益を保証するものではありません**。デモ口座で挙動を確認するための最小構成プロトタイプです。

## ファイル

- `XAUUSD_LowLot_Grid_Prototype.mq4` - MT4 / MetaEditorでコンパイルするEA本体

## 基本仕様

- 対象シンボルはXAUUSDです。
  - ブローカーによって `XAUUSDm` などの接尾辞が付く場合があります。EAはシンボル名に `XAUUSD` を含むチャートでのみ新規エントリーします。
- EA管理対象は、同一シンボルかつ同一 `MagicNumber` のBuyポジションのみです。
- ポジションがない場合、Buyで1ポジションを成行エントリーします。
- 価格が逆行した場合、既存Buyポジションの最安建値から `GridStepUSD` ごとにナンピンBuyします。
- 最大ポジション数は `MaxPositions` で制限します。
- 合計ロットが `MaxTotalLots` を超える新規エントリーは行いません。
- 各ポジションの損益（`OrderProfit + OrderSwap + OrderCommission`）が `TakeProfitPerPositionUSD` 以上になった場合、そのポジションだけ個別決済します。
- `EnableTrading=false` の場合、新規エントリーとナンピンは停止します。
  - 既存ポジションの個別利確管理は継続します。
- チャート左上にEA名、口座残高、有効証拠金、保有ポジション数、合計ロット、含み損益などを表示します。

## input項目

| 項目 | 初期値 | 説明 |
| --- | ---: | --- |
| `EnableTrading` | `true` | `true` の場合のみ新規エントリー・ナンピンを行います。`false` でも既存ポジションの個別利確は継続します。 |
| `InitialLot` | `0.01` | 初回エントリーおよびナンピン時のロットです。 |
| `GridStepUSD` | `5.0` | ナンピン間隔です。XAUUSDの価格差で5.0ドル逆行したら追加Buyを検討します。 |
| `MaxPositions` | `5` | EAが保有する最大Buyポジション数です。 |
| `MaxTotalLots` | `0.05` | EAが保有する最大合計ロットです。 |
| `TakeProfitPerPositionUSD` | `1.0` | 各ポジションを個別決済する利益額です。口座通貨ベースで判定します。 |
| `MagicNumber` | `20260506` | EAの注文を識別する番号です。他EAと重複しない値を推奨します。 |
| `Slippage` | `30` | `OrderSend` / `OrderClose` の許容スリッページ（ポイント）です。 |

## 使い方

1. MT4のデータフォルダを開きます。
2. `MQL4/Experts/` フォルダに `XAUUSD_LowLot_Grid_Prototype.mq4` をコピーします。
3. MetaEditorでファイルを開き、コンパイルします。
4. MT4のナビゲーターでEAを更新し、XAUUSDチャートに適用します。
5. まずは必ずデモ口座で、低ロット・低リスク設定から検証してください。
6. 新規エントリーを止めたい場合は、EA設定で `EnableTrading=false` にしてください。既存ポジションの個別利確管理は継続します。

## 注意事項

- 本EAは検証用プロトタイプであり、利益を保証するものではありません。
- ナンピンは相場が一方向に大きく動いた場合、含み損が急拡大する可能性があります。
- ゴールド（XAUUSD）はボラティリティが大きく、スプレッドや約定条件もブローカーにより異なります。
- `MaxPositions`、`MaxTotalLots`、`GridStepUSD` は必ず口座資金と許容リスクに合わせて調整してください。
- ライブ口座で使用する前に、デモ口座とストラテジーテスターで十分に検証してください。
- `OrderSend` / `OrderClose` が失敗した場合、EAは `GetLastError()` の値をExpertsログへ出力します。
