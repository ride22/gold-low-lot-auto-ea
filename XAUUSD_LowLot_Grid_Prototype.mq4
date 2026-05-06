//+------------------------------------------------------------------+
//| XAUUSD Low Lot Grid Prototype EA                                 |
//| 検証用プロトタイプ：利益を保証するものではありません             |
//+------------------------------------------------------------------+
#property strict
#property version   "1.00"
#property description "XAUUSD low-lot defensive grid prototype EA for MT4."

//---- input parameters
input bool   EnableTrading                = true;     // 新規エントリーを許可するか
input double InitialLot                   = 0.01;     // 初期ロット / ナンピン時のロット
input double GridStepUSD                  = 5.0;      // 逆行時のナンピン間隔（XAUUSDの価格差USD）
input int    MaxPositions                 = 5;        // 最大保有ポジション数
input double MaxTotalLots                 = 0.05;     // 最大合計ロット
input double TakeProfitPerPositionUSD     = 1.0;      // 1ポジションごとの個別利確額（口座通貨）
input int    MagicNumber                  = 20260506; // EA識別用マジックナンバー
input int    Slippage                     = 30;       // 許容スリッページ（ポイント）

string EA_NAME = "XAUUSD Low Lot Grid Prototype";

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // XAUUSDチャートでの利用を想定。ブローカーにより末尾記号が付くため部分一致で確認します。
   if(!IsTargetSymbol())
   {
      Print(EA_NAME, ": 注意 - このEAはXAUUSD向けです。現在のシンボル: ", Symbol());
   }

   Print(EA_NAME, " initialized. This is a demo/testing prototype and does not guarantee profit.");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Comment("");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // 既存ポジションの個別利確はEnableTrading=falseでも継続します。
   ManageIndividualTakeProfit();

   if(EnableTrading)
   {
      ManageBuyEntries();
   }

   DrawStatusPanel();
}

//+------------------------------------------------------------------+
//| Buyエントリーとナンピンを管理                                    |
//+------------------------------------------------------------------+
void ManageBuyEntries()
{
   // 対象外シンボルでは誤発注防止のため新規エントリーしません。
   if(!IsTargetSymbol())
   {
      return;
   }

   int positionCount = CountOwnBuyPositions();
   double totalLots = GetOwnTotalLots();

   // ポジションがない場合はBuyで1ポジションを成行エントリーします。
   if(positionCount == 0)
   {
      OpenBuyPosition();
      return;
   }

   if(positionCount >= MaxPositions)
   {
      return;
   }

   // Buyポジションの最安建値からGridStepUSD以上逆行したら追加Buyします。
   double lowestOpenPrice = GetLowestBuyOpenPrice();
   RefreshRates();
   if(lowestOpenPrice > 0.0 && Ask <= lowestOpenPrice - GridStepUSD)
   {
      if(totalLots + NormalizeLot(InitialLot) <= MaxTotalLots + 0.0000001)
      {
         OpenBuyPosition();
      }
      else
      {
         Print(EA_NAME, ": MaxTotalLotsを超えるため追加エントリーしません。現在合計ロット=",
               DoubleToString(totalLots, 2), ", MaxTotalLots=", DoubleToString(MaxTotalLots, 2));
      }
   }
}

//+------------------------------------------------------------------+
//| Buyポジションを成行で発注                                        |
//+------------------------------------------------------------------+
void OpenBuyPosition()
{
   double totalLots = GetOwnTotalLots();
   double lots = NormalizeLot(InitialLot);

   // 合計ロット上限を超える新規発注は行いません。
   if(lots <= 0.0 || totalLots + lots > MaxTotalLots + 0.0000001)
   {
      Print(EA_NAME, ": ロット条件により発注しません。lots=", DoubleToString(lots, 2),
            ", totalLots=", DoubleToString(totalLots, 2),
            ", MaxTotalLots=", DoubleToString(MaxTotalLots, 2));
      return;
   }

   RefreshRates();
   ResetLastError();
   int ticket = OrderSend(Symbol(), OP_BUY, lots, Ask, Slippage, 0, 0,
                          EA_NAME, MagicNumber, 0, clrBlue);

   if(ticket < 0)
   {
      int errorCode = GetLastError();
      Print(EA_NAME, ": OrderSend failed. GetLastError=", errorCode);
   }
   else
   {
      Print(EA_NAME, ": Buy order opened. ticket=", ticket,
            ", lots=", DoubleToString(lots, 2),
            ", price=", DoubleToString(Ask, Digits));
   }
}

//+------------------------------------------------------------------+
//| 各ポジションの個別利確管理                                      |
//+------------------------------------------------------------------+
void ManageIndividualTakeProfit()
{
   RefreshRates();

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         continue;
      }

      if(!IsOwnBuyOrder())
      {
         continue;
      }

      // OrderProfitにスワップと手数料を加えた実損益で判定します。
      double orderProfit = OrderProfit() + OrderSwap() + OrderCommission();
      if(orderProfit >= TakeProfitPerPositionUSD)
      {
         int ticket = OrderTicket();
         double lots = OrderLots();

         RefreshRates();
         ResetLastError();
         bool closed = OrderClose(ticket, lots, Bid, Slippage, clrGreen);

         if(!closed)
         {
            int errorCode = GetLastError();
            Print(EA_NAME, ": OrderClose failed. ticket=", ticket,
                  ", GetLastError=", errorCode);
         }
         else
         {
            Print(EA_NAME, ": Buy order closed by individual TP. ticket=", ticket,
                  ", profit=", DoubleToString(orderProfit, 2));
         }
      }
   }
}

//+------------------------------------------------------------------+
//| XAUUSD系シンボルか判定                                           |
//+------------------------------------------------------------------+
bool IsTargetSymbol()
{
   return(StringFind(Symbol(), "XAUUSD", 0) >= 0);
}

//+------------------------------------------------------------------+
//| EA対象のBuy注文か判定                                            |
//+------------------------------------------------------------------+
bool IsOwnBuyOrder()
{
   return(OrderSymbol() == Symbol()
          && OrderMagicNumber() == MagicNumber
          && OrderType() == OP_BUY);
}

//+------------------------------------------------------------------+
//| EA対象Buyポジション数                                            |
//+------------------------------------------------------------------+
int CountOwnBuyPositions()
{
   int count = 0;

   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         continue;
      }

      if(IsOwnBuyOrder())
      {
         count++;
      }
   }

   return(count);
}

//+------------------------------------------------------------------+
//| EA対象Buyの合計ロット                                            |
//+------------------------------------------------------------------+
double GetOwnTotalLots()
{
   double lots = 0.0;

   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         continue;
      }

      if(IsOwnBuyOrder())
      {
         lots += OrderLots();
      }
   }

   return(lots);
}

//+------------------------------------------------------------------+
//| EA対象Buyの合計含み損益                                          |
//+------------------------------------------------------------------+
double GetOwnFloatingProfit()
{
   double profit = 0.0;

   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         continue;
      }

      if(IsOwnBuyOrder())
      {
         profit += OrderProfit() + OrderSwap() + OrderCommission();
      }
   }

   return(profit);
}

//+------------------------------------------------------------------+
//| EA対象Buyの最安建値                                              |
//+------------------------------------------------------------------+
double GetLowestBuyOpenPrice()
{
   double lowestPrice = 0.0;

   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         continue;
      }

      if(IsOwnBuyOrder())
      {
         if(lowestPrice == 0.0 || OrderOpenPrice() < lowestPrice)
         {
            lowestPrice = OrderOpenPrice();
         }
      }
   }

   return(lowestPrice);
}

//+------------------------------------------------------------------+
//| ブローカーのロット制約に合わせて正規化                          |
//+------------------------------------------------------------------+
double NormalizeLot(double requestedLot)
{
   double minLot = MarketInfo(Symbol(), MODE_MINLOT);
   double maxLot = MarketInfo(Symbol(), MODE_MAXLOT);
   double lotStep = MarketInfo(Symbol(), MODE_LOTSTEP);

   if(lotStep <= 0.0)
   {
      lotStep = 0.01;
   }

   double lots = requestedLot;
   lots = MathMax(lots, minLot);
   lots = MathMin(lots, maxLot);
   lots = MathFloor(lots / lotStep) * lotStep;

   return(NormalizeDouble(lots, 2));
}

//+------------------------------------------------------------------+
//| チャート左上に稼働状況を表示                                    |
//+------------------------------------------------------------------+
void DrawStatusPanel()
{
   string status = "";
   status += "EA名: " + EA_NAME + "\n";
   status += "新規エントリー: " + (EnableTrading ? "有効" : "停止") + "\n";
   status += "口座残高: " + DoubleToString(AccountBalance(), 2) + "\n";
   status += "有効証拠金: " + DoubleToString(AccountEquity(), 2) + "\n";
   status += "保有ポジション数: " + IntegerToString(CountOwnBuyPositions()) + "\n";
   status += "合計ロット: " + DoubleToString(GetOwnTotalLots(), 2) + "\n";
   status += "含み損益: " + DoubleToString(GetOwnFloatingProfit(), 2) + "\n";
   status += "注意: 検証用EAであり、利益を保証しません。";

   Comment(status);
}
//+------------------------------------------------------------------+
