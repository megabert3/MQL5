//+------------------------------------------------------------------+
//|                                                      SRZones.mq5 |
//|                     Индикатор уровней S/R                         |
//|                     ATR → ZigZag → LevelTracker → Прямоугольники  |
//+------------------------------------------------------------------+
#property copyright "akhalimov"
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 1
#property indicator_plots   1
#property indicator_type1   DRAW_SECTION
#property indicator_color1  clrDodgerBlue
#property indicator_width1  2

#include <../Files/My/Claude/CAtr.mqh>
#include <../Files/My/Claude/CZigZagAdapt.mqh>
#include <../Files/My/Claude/Levels/CLevelTracker.mqh>
#include <../Files/My/Claude/Draw/CSRDraw.mqh>

//--- ATR параметры
input int    InpAtrPeriod       = 14;    // ATR период

//--- ZigZag параметры
input double InpZzMultiplier    = 1.5;   // ZigZag: множитель ATR → deviation

//--- Уровни
input double InpZoneWidthFactor = 0.3;   // Уровни: полуширина зоны (× ATR)
input int    InpLookbackBars    = 300;   // Уровни: глубина анализа (баров)

//--- Цвета
input color  InpMirrorColor     = clrCrimson;       // Цвет зеркальных уровней
input color  InpUntestedColor   = clrRoyalBlue;     // Цвет непротестированных

//--- Буфер ZigZag
double g_zigzagBuff[];

//--- Объекты
CAtr           *g_atr;
CZigZagAdapt   *g_zigzag;
CLevelTracker  *g_tracker;

//+------------------------------------------------------------------+
int OnInit() {
  SetIndexBuffer(0, g_zigzagBuff, INDICATOR_DATA);
  PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, 0.0);

  g_atr     = new CAtr(InpAtrPeriod);
  g_zigzag  = new CZigZagAdapt();
  g_tracker = new CLevelTracker();

  return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
  CSRDraw::clearAll("LVL_");
  delete g_atr;
  delete g_zigzag;
  delete g_tracker;
}

//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[]) {

  if (rates_total < InpAtrPeriod + 1) return 0;

  //--- Первый запуск — сброс
  int start = prev_calculated;
  if (prev_calculated == 0) {
    ArrayInitialize(g_zigzagBuff, 0.0);
    g_zigzag.reset(g_zigzagBuff);
    g_atr.reset();
    g_tracker.reset();
    start = 0;
  }

  //--- Расчёт ATR и ZigZag
  for (int i = start; i < rates_total; i++) {
    double atr = g_atr.calculate(high, low, close, i);
    double deviation = atr * InpZzMultiplier;
    g_zigzag.calculate(g_zigzagBuff, i, close, high, low, deviation);
  }

  //--- Получаем экстремумы → конвертируем в ExtremePoint
  CZigZagAdapt::Extreme zzExtremes[];
  g_zigzag.getExtremes(zzExtremes);

  int extCount = ArraySize(zzExtremes);
  ExtremePoint extremes[];
  ArrayResize(extremes, extCount);
  for (int i = 0; i < extCount; i++) {
    extremes[i].barIndex = zzExtremes[i].index;
    extremes[i].price    = zzExtremes[i].price;
    extremes[i].type     = (zzExtremes[i].type == CZigZagAdapt::BOTTOM) ? 1 : -1;
  }

  //--- Рассчитываем уровни
  double atr = g_atr.getLastAtr();
  double zoneWidth = atr * InpZoneWidthFactor;

  g_tracker.calculate(extremes, high, low, rates_total,
                      zoneWidth, InpLookbackBars);

  //--- Отрисовка
  CSRDraw::clearAll("LVL_");

  PriceLevel levels[];
  g_tracker.getLevels(levels);

  for (int i = 0; i < ArraySize(levels); i++) {
    int fb = levels[i].startBar;
    int lb = (levels[i].endBar < 0) ? rates_total - 1 : levels[i].endBar;
    if (fb < 0) fb = 0;
    if (lb >= rates_total) lb = rates_total - 1;

    string name = "LVL_" + IntegerToString(i);
    color clr = levels[i].isMirror ? InpMirrorColor : InpUntestedColor;

    CSRDraw::drawZone(name, time[fb], time[lb],
                      levels[i].lower, levels[i].upper, clr);
  }

  return rates_total;
}
