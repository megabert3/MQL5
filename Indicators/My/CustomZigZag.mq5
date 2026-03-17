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

#property indicator_type2   DRAW_SECTION
#property indicator_color2  clrSilver
#property indicator_width2  1

input double deviation = 10;

enum SearchMod {
  NONE,
  TOP,
  BOTTOM
};

double zigZagBuffer[];
double legBuffer[];

double candidatePrice;
int candidateIndex;

double lastExtrenePrice;
int lastExtremeIndex;

double legStartPrice;
int legStartIndex;
double legEndPrice;
int legEndIndex;

SearchMod search;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- indicator buffers mapping
    SetIndexBuffer(0, zigZagBuffer, INDICATOR_DATA);
    SetIndexBuffer(1, legBuffer, INDICATOR_DATA);

    PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, 0.0);
    PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, 0.0);

    ArrayInitialize(zigZagBuffer, 0.0);
    ArrayInitialize(legBuffer, 0.0);

    candidateIndex = 0;
    candidatePrice = 0.0;
    lastExtremeIndex = 0;
    lastExtrenePrice = 0.0;
    legStartPrice = 0.0;
    legStartIndex = 0;
    legEndPrice = 0.0;
    legEndIndex = 0;
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
      ArrayInitialize(legBuffer, 0.0);
      candidatePrice = 0.0;
      candidateIndex = 0;
      lastExtrenePrice = 0.0;
      lastExtremeIndex = 0;
      legStartPrice = 0.0;
      legStartIndex = 0;
      legEndPrice = 0.0;
      legEndIndex = 0;
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
          legStartIndex = i;
          legStartPrice = high[i];
          legBuffer[legStartIndex] = legStartPrice;
          zigZagBuffer[i] = high[i];
          search = BOTTOM;
          printComment();

        } else if (downDev) {
          lastExtrenePrice = candidatePrice;
          lastExtremeIndex = candidateIndex;
          candidatePrice = low[i];
          candidateIndex = i;
          legStartIndex = i;
          legStartPrice = low[i];
          legBuffer[legEndIndex] = legStartPrice;
          zigZagBuffer[i] = low[i];
          search = TOP;
          printComment();
        }

      } else if (search == BOTTOM) {
        if (candidatePrice < high[i]) {
          Print("Ищем BOTTOM обновили High");
          zigZagBuffer[candidateIndex] = 0.0;
          legBuffer[legEndIndex] = 0.0;
          legBuffer[legStartIndex] = 0.0;
          candidatePrice = high[i];
          candidateIndex = i;
          legStartPrice = high[i];
          legStartIndex = i;
          legEndPrice = high[i];
          legEndIndex = i;
          legBuffer[legStartIndex] = legStartPrice;
          zigZagBuffer[candidateIndex] = candidatePrice;
          printComment();
        }

        if (candidatePrice - low[i] > deviation * _Point) {
          Print("Нашли BOTTOM теперь ищем TOP");
          legBuffer[legEndIndex] = 0.0;
          legBuffer[legStartIndex] = 0.0;
          lastExtrenePrice = candidatePrice;
          lastExtremeIndex = candidateIndex;
          candidatePrice = low[i];
          candidateIndex = i;
          legStartIndex = i;
          legStartPrice = low[i];
          legEndIndex = i;
          legEndPrice = low[i];
          legBuffer[legStartIndex] = legStartPrice;
          zigZagBuffer[lastExtremeIndex] = lastExtrenePrice;
          search = TOP;
          printComment();
        }
      } else if (search == TOP) {
        if (candidatePrice > low[i]) {
          Print("Ищем TOP обновили low");
          zigZagBuffer[candidateIndex] = 0.0;
          legBuffer[legEndIndex] = 0.0;
          legBuffer[legStartIndex] = 0.0;
          candidatePrice = low[i];
          candidateIndex = i;
          legStartPrice = low[i];
          legStartIndex = i;
          legEndPrice = low[i];
          legEndIndex = i;
          legBuffer[legStartIndex] = legStartPrice;
          zigZagBuffer[candidateIndex] = candidatePrice;
          printComment();
        }

        if (high[i] - candidatePrice > deviation * _Point) {
          Print("Нашли TOP теперь ищем BOTTOM");
          legBuffer[legEndIndex] = 0.0;
          legBuffer[legStartIndex] = 0.0;
          lastExtrenePrice = candidatePrice;
          lastExtremeIndex = candidateIndex;
          candidatePrice = high[i];
          candidateIndex = i;
          legStartIndex = i;
          legStartPrice = high[i];
          legEndIndex = i;
          legEndPrice = high[i];
          legBuffer[legStartIndex] = legStartPrice;
          zigZagBuffer[lastExtremeIndex] = lastExtrenePrice;
          search = BOTTOM;
          printComment();
        }
      }

      if (legStartIndex != i) {
        if (search == BOTTOM) {
          legEndIndex = i;
          legEndPrice = low[i];
        }
        else if (search == TOP) {
          legEndIndex = i;
          legEndPrice = high[i]; 
        }
        legBuffer[legEndIndex] = legEndPrice;
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
    "lastExtremeIndex: = " + lastExtremeIndex + "\n" +
    "legStartPrice: = " + legStartPrice + "\n" +
    "legStartIndex: = " + legStartIndex + "\n" +
    "legEndPrice: = " + legEndPrice + "\n" +
    "legEndIndex: = " + legEndIndex;
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