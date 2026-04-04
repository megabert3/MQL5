//+------------------------------------------------------------------+
//|                                               CLevelTracker.mqh  |
//|                     Отслеживание жизненного цикла уровней         |
//|                     Зеркальные (ретестированные) и непротестиров.  |
//+------------------------------------------------------------------+
#property copyright "akhalimov"
#property version   "1.00"

//+------------------------------------------------------------------+
//| Уровень с жизненным циклом                                       |
//+------------------------------------------------------------------+
struct PriceLevel {
  double upper;      // верхняя граница зоны
  double lower;      // нижняя граница зоны
  int    startBar;   // начало отрисовки
  int    endBar;     // конец отрисовки (-1 = до текущего бара)
  bool   isMirror;   // true = зеркальный (ретестирован)
  int    originType; // 1 = от пика, -1 = от впадины
};

//+------------------------------------------------------------------+
//| Входной экстремум (чтобы не зависеть от CZigZagAdapt)           |
//+------------------------------------------------------------------+
struct ExtremePoint {
  int    barIndex;
  double price;
  int    type;       // 1 = пик, -1 = впадина
};

//+------------------------------------------------------------------+
//| Трекер уровней                                                   |
//| Для каждого экстремума ZigZag определяет:                        |
//|   - Цена вернулась к нему? → зеркальный (красный)               |
//|   - Не вернулась? → непротестированный (синий)                   |
//+------------------------------------------------------------------+
class CLevelTracker {
  private:
    PriceLevel m_levels[];

  public:
    void reset() { ArrayFree(m_levels); }

    int getLevelCount() const { return ArraySize(m_levels); }

    void getLevels(PriceLevel &dst[]) const {
      int size = ArraySize(m_levels);
      ArrayResize(dst, size);
      for (int i = 0; i < size; i++)
        dst[i] = m_levels[i];
    }

    // extremes    — экстремумы ZigZag (отсортированы по barIndex)
    // high[], low[] — ценовые массивы
    // totalBars   — общее кол-во баров
    // zoneWidth   — полуширина зоны (напр. ATR × factor)
    // lookbackBars— анализировать только последние N баров
    void calculate(const ExtremePoint &extremes[],
                   const double &high[],
                   const double &low[],
                   int totalBars,
                   double zoneWidth,
                   int lookbackBars) {

      ArrayFree(m_levels);

      int n = ArraySize(extremes);
      if (n == 0) return;

      int lookbackStart = totalBars - lookbackBars;
      if (lookbackStart < 0) lookbackStart = 0;

      for (int i = 0; i < n; i++) {
        if (extremes[i].barIndex < lookbackStart) continue;

        double price = extremes[i].price;
        double upper = price + zoneWidth;
        double lower = price - zoneWidth;
        int formBar = extremes[i].barIndex;

        // Ищем: цена ушла от экстремума, потом вернулась?
        bool leftZone = false;
        int retestBar = -1;

        for (int b = formBar + 1; b < totalBars; b++) {
          bool inZone = (high[b] >= lower && low[b] <= upper);

          if (!leftZone) {
            if (!inZone) leftZone = true;
          } else {
            if (inZone) {
              retestBar = b;
              break;
            }
          }
        }

        PriceLevel level;
        level.upper      = upper;
        level.lower      = lower;
        level.originType = extremes[i].type;

        if (retestBar > 0) {
          // Зеркальный — от формирования до ретеста
          level.isMirror = true;
          level.startBar = formBar;
          level.endBar   = retestBar;
        } else {
          // Непротестированный — от формирования до текущего бара
          level.isMirror = false;
          level.startBar = formBar;
          level.endBar   = -1;  // -1 = до конца графика
        }

        pushLevel(level);
      }
    }

  private:
    void pushLevel(const PriceLevel &level) {
      int size = ArraySize(m_levels);
      ArrayResize(m_levels, size + 1);
      m_levels[size] = level;
    }
};
