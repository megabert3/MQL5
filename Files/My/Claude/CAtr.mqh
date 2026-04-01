//+------------------------------------------------------------------+
//|                                                         CAtr.mqh |
//|                           Расчёт ATR без привязки к iATR         |
//+------------------------------------------------------------------+
#property copyright "akhalimov"
#property version   "1.00"

//+------------------------------------------------------------------+
//| Класс расчёта Average True Range по массивам OHLC                |
//| Работает с массивами напрямую — не требует хэндла iATR.          |
//| Можно использовать в индикаторах, EA и при бэктестинге.          |
//+------------------------------------------------------------------+
class CAtr {
  private:
    int m_period;
    double m_lastAtr;
    int m_calculatedBars;

  public:
    CAtr(int period) {
      m_period = period;
      m_lastAtr = 0.0;
      m_calculatedBars = 0;
    }

    int getPeriod() const { return m_period; }
    double getLastAtr() const { return m_lastAtr; }

    void reset() {
      m_lastAtr = 0.0;
      m_calculatedBars = 0;
    }

    // True Range одной свечи
    static double trueRange(double high, double low, double prevClose) {
      double hl = high - low;
      double hc = MathAbs(high - prevClose);
      double lc = MathAbs(low - prevClose);
      return MathMax(hl, MathMax(hc, lc));
    }

    // Рассчитать ATR для конкретного бара по массивам
    // Возвращает ATR или 0.0 если недостаточно данных
    double calculate(const double &high[],
                     const double &low[],
                     const double &close[],
                     int index) {
      if (index < 1) {
        m_lastAtr = high[0] - low[0];
        m_calculatedBars = 1;
        return m_lastAtr;
      }

      if (index < m_period) {
        // Недостаточно данных для полного ATR — считаем простое среднее по доступным барам
        double sum = high[0] - low[0]; // первый бар без prevClose
        for (int i = 1; i <= index; i++) {
          sum += trueRange(high[i], low[i], close[i - 1]);
        }
        m_lastAtr = sum / (index + 1);
        m_calculatedBars = index + 1;
        return m_lastAtr;
      }

      // Полный расчёт: если это первый полный период — SMA, иначе — EMA (Wilder smoothing)
      if (m_calculatedBars < m_period) {
        // Первый полный расчёт — SMA от True Range
        double sum = high[0] - low[0];
        for (int i = 1; i < m_period; i++) {
          sum += trueRange(high[i], low[i], close[i - 1]);
        }
        m_lastAtr = sum / m_period;
        m_calculatedBars = m_period;

        // Досчитываем оставшиеся бары через Wilder smoothing
        for (int i = m_period; i <= index; i++) {
          double tr = trueRange(high[i], low[i], close[i - 1]);
          m_lastAtr = (m_lastAtr * (m_period - 1) + tr) / m_period;
          m_calculatedBars = i + 1;
        }
      } else {
        // Инкрементальный расчёт — Wilder smoothing
        double tr = trueRange(high[index], low[index], close[index - 1]);
        m_lastAtr = (m_lastAtr * (m_period - 1) + tr) / m_period;
        m_calculatedBars = index + 1;
      }

      return m_lastAtr;
    }
};
