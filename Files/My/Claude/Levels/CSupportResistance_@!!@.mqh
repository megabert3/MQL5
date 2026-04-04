//+------------------------------------------------------------------+
//|                                          CSupportResistance.mqh  |
//|                     Базовый класс уровней поддержки/сопротивления |
//+------------------------------------------------------------------+
#property copyright "akhalimov"
#property version   "1.00"

//+------------------------------------------------------------------+
//| Входная точка — экстремум для кластеризации                      |
//+------------------------------------------------------------------+
struct SRPoint {
  double price;
  int    type;      // 1 = peak (сопротивление), -1 = trough (поддержка)
  int    barIndex;  // индекс бара для расчёта свежести
};

//+------------------------------------------------------------------+
//| Зона поддержки/сопротивления                                     |
//+------------------------------------------------------------------+
struct SRZone {
  double center;      // центр зоны (среднее)
  double upper;       // верхняя граница
  double lower;       // нижняя граница
  int    firstBar;    // индекс бара первой точки кластера
  int    lastBar;     // индекс бара последней точки кластера
  int    touchCount;  // общее кол-во касаний
  int    peakCount;   // кол-во пиков (сопротивление)
  int    troughCount; // кол-во впадин (поддержка)
  bool   isMirror;    // зеркальный уровень (и пики, и впадины)
  double score;       // сила уровня
};

//+------------------------------------------------------------------+
//| Абстрактный базовый класс                                        |
//| Наследники реализуют calculate() с конкретным алгоритмом.         |
//| calculate() принимает ВСЕ экстремумы и строит ВСЕ зоны.          |
//+------------------------------------------------------------------+
class CSupportResistance {
  protected:
    SRZone m_zones[];

  public:
    virtual ~CSupportResistance() {}

    // Полный пересчёт всех зон по всем точкам
    virtual void calculate(const SRPoint &points[], int totalBars) {
      ArrayFree(m_zones);
    }

    // Сброс — при смене таймфрейма, символа и т.д.
    void reset() { ArrayFree(m_zones); }

    int getZoneCount() const { return ArraySize(m_zones); }

    void getZones(SRZone &dst[]) const {
      int size = ArraySize(m_zones);
      ArrayResize(dst, size);
      for (int i = 0; i < size; i++)
        dst[i] = m_zones[i];
    }

  protected:
    //--- Внутренние утилиты для наследников ---

    // Построить зону из группы точек (indices — индексы в массиве points)
    void buildZone(const SRPoint &points[], const int &indices[],
                   int totalBars, SRZone &zone) {
      int count = ArraySize(indices);
      if (count <= 0) return;

      double minPrice = points[indices[0]].price;
      double maxPrice = points[indices[0]].price;
      double sum = 0.0;
      int peaks = 0;
      int troughs = 0;
      int oldestBar = points[indices[0]].barIndex;
      int newestBar = points[indices[0]].barIndex;

      for (int i = 0; i < count; i++) {
        int idx = indices[i];
        double p = points[idx].price;
        sum += p;
        if (p < minPrice) minPrice = p;
        if (p > maxPrice) maxPrice = p;
        if (points[idx].type == 1) peaks++;
        else                        troughs++;
        if (points[idx].barIndex < oldestBar)
          oldestBar = points[idx].barIndex;
        if (points[idx].barIndex > newestBar)
          newestBar = points[idx].barIndex;
      }

      zone.center      = sum / count;
      zone.upper       = maxPrice;
      zone.lower       = minPrice;
      zone.firstBar    = oldestBar;
      zone.lastBar     = newestBar;
      zone.touchCount  = count;
      zone.peakCount   = peaks;
      zone.troughCount = troughs;
      zone.isMirror    = (peaks > 0 && troughs > 0);

      double recency = (totalBars > 0) ? (double)newestBar / totalBars : 1.0;
      double mirrorBonus = zone.isMirror ? 1.5 : 1.0;
      zone.score = count * mirrorBonus * (0.5 + 0.5 * recency);
    }

    void pushZone(const SRZone &zone) {
      int size = ArraySize(m_zones);
      ArrayResize(m_zones, size + 1);
      m_zones[size] = zone;
    }
};
