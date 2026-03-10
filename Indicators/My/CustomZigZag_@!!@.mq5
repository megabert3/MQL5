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
    if (candidateIndex >= rates_total) return rates_total;
    if (rates_total < 2) return 0;

    if (prev_calculated == 0) {
      ArrayInitialize(zigZagBuffer, 0.0);
      ArrayInitialize(legBuffer, 0.0);
      candidatePrice = 0.0;
      candidateIndex = 0;
      lastExtrenePrice = 0.0;
      lastExtremeIndex = 0;
      search = NONE;
    }

    int start = prev_calculated > 0 ? prev_calculated - 1 : 0;
    for (int i = start; i < rates_total; i++) {
      legBuffer[i] = 0.0;

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

        } else if (downDev) {
          lastExtrenePrice = candidatePrice;
          lastExtremeIndex = candidateIndex;
          candidatePrice = low[i];
          candidateIndex = i;
          zigZagBuffer[i] = low[i];
          search = TOP;
        }

      } else if (search == BOTTOM) {
        if (candidatePrice < high[i]) {
          zigZagBuffer[candidateIndex] = 0.0;
          candidatePrice = high[i];
          candidateIndex = i;
          zigZagBuffer[candidateIndex] = candidatePrice;
        }

        if (candidatePrice - low[i] > deviation * _Point) {
          lastExtrenePrice = candidatePrice;
          lastExtremeIndex = candidateIndex;
          candidatePrice = low[i];
          candidateIndex = i;
          zigZagBuffer[lastExtremeIndex] = lastExtrenePrice;
          legBuffer[lastExtremeIndex] = 0.0;
          search = TOP;
        }
      } else if (search == TOP) {
        if (candidatePrice > low[i]) {
          zigZagBuffer[candidateIndex] = 0.0;
          candidatePrice = low[i];
          candidateIndex = i;
          zigZagBuffer[candidateIndex] = candidatePrice;
        }

        if (high[i] - candidatePrice > deviation * _Point) {
          lastExtrenePrice = candidatePrice;
          lastExtremeIndex = candidateIndex;
          candidatePrice = high[i];
          candidateIndex = i;
          zigZagBuffer[lastExtremeIndex] = lastExtrenePrice;
          legBuffer[lastExtremeIndex] = 0.0;
          search = BOTTOM;
        }
      }

      if (candidateIndex != i) {
        if (search == BOTTOM) legBuffer[i] = low[i];
        else if (search == TOP) legBuffer[i] = high[i];

      } else {
        legBuffer[i] = candidatePrice;
      }
    }
//--- return value of prev_calculated for next call
   return(rates_total);
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