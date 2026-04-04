//+------------------------------------------------------------------+
//|                                                     CSRDraw.mqh  |
//|                     Отрисовка зон S/R прямоугольниками на графике |
//+------------------------------------------------------------------+
#property copyright "akhalimov"
#property version   "1.00"

#include "../Levels/CSupportResistance.mqh"

//+------------------------------------------------------------------+
//| Статический класс для отрисовки зон S/R                          |
//| Поддержка — красный, сопротивление — синий, зеркальный — фиолет  |
//+------------------------------------------------------------------+
class CSRDraw {
  public:
    // Нарисовать один прямоугольник зоны
    static void drawZone(const string name,
                         datetime startTime,
                         datetime endTime,
                         double lower,
                         double upper,
                         color clr,
                         int opacity = 50) {

      long chartId = 0;

      if (ObjectFind(chartId, name) < 0)
        ObjectCreate(chartId, name, OBJ_RECTANGLE, 0,
                     startTime, lower, endTime, upper);
      else {
        ObjectSetInteger(chartId, name, OBJPROP_TIME, 0, startTime);
        ObjectSetDouble(chartId, name, OBJPROP_PRICE, 0, lower);
        ObjectSetInteger(chartId, name, OBJPROP_TIME, 1, endTime);
        ObjectSetDouble(chartId, name, OBJPROP_PRICE, 1, upper);
      }

      ObjectSetInteger(chartId, name, OBJPROP_COLOR, clr);
      ObjectSetInteger(chartId, name, OBJPROP_FILL, true);
      ObjectSetInteger(chartId, name, OBJPROP_BACK, true);
      ObjectSetInteger(chartId, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(chartId, name, OBJPROP_WIDTH, 1);
    }

    // Нарисовать все зоны из массива
    static void drawZones(const SRZone &zones[],
                          datetime startTime,
                          datetime endTime,
                          const string prefix = "SR_") {

      int size = ArraySize(zones);
      for (int i = 0; i < size; i++) {
        string name = prefix + IntegerToString(i);
        color clr = zoneColor(zones[i]);
        drawZone(name, startTime, endTime,
                 zones[i].lower, zones[i].upper, clr);
      }
    }

    // Удалить все объекты с префиксом
    static void clearAll(const string prefix = "SR_") {
      ObjectsDeleteAll(0, prefix);
    }

  private:
    static color zoneColor(const SRZone &zone) {
      if (zone.isMirror)            return clrMediumOrchid;  // фиолетовый
      if (zone.peakCount > 0)       return clrRoyalBlue;     // сопротивление
      return clrCrimson;                                      // поддержка
    }
};
