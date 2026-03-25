//+------------------------------------------------------------------+
//|                                                 CustomZigZag.mq5 |
//|                                  Copyright 2026, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 2
#property indicator_plots   2

#property indicator_type1   DRAW_SECTION
#property indicator_color1  clrRed
#property indicator_width1  2

input double deviation = 10;

enum SearchMod {
  NONE,
  TOP,
  BOTTOM
};

double zigZagBuffer[];

double candidatePrice;
int candidateIndex;

double lastExtrenePrice;
int lastExtremeIndex;

SearchMod search;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- indicator buffers mapping
    SetIndexBuffer(0, zigZagBuffer, INDICATOR_DATA);
    PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, 0.0);
    ArrayInitialize(zigZagBuffer, 0.0);

    candidateIndex = 0;
    candidatePrice = 0.0;
    lastExtremeIndex = 0;
    lastExtrenePrice = 0.0;
    search = NONE;
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int32_t rates_total,
                const int32_t prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int32_t &spread[])
  {
//---
    if (rates_total < 2) return 0;

    if (prev_calculated == 0) {
      ArrayInitialize(zigZagBuffer, 0.0);
      candidatePrice = 0.0;
      candidateIndex = 0;
      lastExtrenePrice = 0.0;
      lastExtremeIndex = 0;
      search = NONE;
    }

    int start = prev_calculated > 0 ? prev_calculated - 1 : 0;
    for (int i = start; i < rates_total; i++) {

      if (search == NONE) {
        if (candidatePrice == 0.0) {
          candidatePrice = close[i];
          candidateIndex = i;
          continue;
        }

        bool upDev = high[i] - candidatePrice > _Point * deviation;
        bool downDev = candidatePrice - low[i] > _Point * deviation;

        if (upDev) {
          lastExtrenePrice = candidatePrice;
          lastExtremeIndex = candidateIndex;
          candidatePrice = high[i];
          candidateIndex = i;
          zigZagBuffer[i] = high[i];
          search = BOTTOM;
          printComment();

        } else if (downDev) {
          lastExtrenePrice = candidatePrice;
          lastExtremeIndex = candidateIndex;
          candidatePrice = low[i];
          candidateIndex = i;
          zigZagBuffer[i] = low[i];
          search = TOP;
          printComment();
        }

      } else if (search == BOTTOM) {
        if (candidatePrice < high[i]) {
          Print("Ищем BOTTOM обновили High");
          zigZagBuffer[candidateIndex] = 0.0;
          candidatePrice = high[i];
          candidateIndex = i;
          zigZagBuffer[candidateIndex] = candidatePrice;
          printComment();
        }

        if (candidateIndex == i) continue;

        if (candidatePrice - low[i] > deviation * _Point) {
          Print("Нашли BOTTOM теперь ищем TOP");
          lastExtrenePrice = candidatePrice;
          lastExtremeIndex = candidateIndex;
          candidatePrice = low[i];
          candidateIndex = i;
          zigZagBuffer[lastExtremeIndex] = lastExtrenePrice;
          search = TOP;
          printComment();
        }
      } else if (search == TOP) {
        if (candidatePrice > low[i]) {
          Print("Ищем TOP обновили low");
          zigZagBuffer[candidateIndex] = 0.0;
          candidatePrice = low[i];
          candidateIndex = i;
          zigZagBuffer[candidateIndex] = candidatePrice;
          printComment();
        }

        if (candidateIndex == i) continue;
        
        if (high[i] - candidatePrice > deviation * _Point) {
          Print("Нашли TOP теперь ищем BOTTOM");
          lastExtrenePrice = candidatePrice;
          lastExtremeIndex = candidateIndex;
          candidatePrice = high[i];
          candidateIndex = i;
          zigZagBuffer[lastExtremeIndex] = lastExtrenePrice;
          search = BOTTOM;
          printComment();
        }
      }
    }
//--- return value of prev_calculated for next call
   return(rates_total);
  }

  void printComment() {
    Comment(getInfo());
  }
  
string getInfo() {
  return 
    "search: = " + EnumToString(search) + "\n" +
    "candidatePrice: = " + candidatePrice + "\n" +
    "candidateIndex: = " + candidateIndex + "\n" +
    "lastExtrenePrice: = " + lastExtrenePrice + "\n" +
    "lastExtremeIndex: = " + lastExtremeIndex;
}
//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
  {
//---
   
  }
//+------------------------------------------------------------------+
//| ChartEvent function                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int32_t id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
  {
//---
   
  }
//+------------------------------------------------------------------+