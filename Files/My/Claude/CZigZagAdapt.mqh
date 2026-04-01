//+------------------------------------------------------------------+
//|                                                CZigZagAdapt.mqh  |
//|                           Адаптивный ZigZag на основе ATR        |
//|                           На базе CZigZag (Albert / akhalimov)   |
//+------------------------------------------------------------------+
#property copyright "akhalimov"
#property version   "1.00"

#include "CAtr.mqh"

//+------------------------------------------------------------------+
//| Адаптивный ZigZag                                                |
//| Отличие от CZigZag: deviation = ATR × multiplier                 |
//| На волатильном рынке фильтрует больше шума,                      |
//| на спокойном — чувствительнее к разворотам.                       |
//| Хранит историю экстремумов для анализа паттернов.                |
//+------------------------------------------------------------------+
class CZigZagAdapt {
  public:
    enum SearchMode {
      NONE,
      TOP,
      BOTTOM
    };

    struct Extreme {
      int index;
      double price;
      SearchMode type;    // BOTTOM = это максимум, TOP = это минимум
    };

  private:
    struct State {
      int candidateIndex;
      double candidatePrice;
      int lastExtremeIndex;
      double lastExtremePrice;
      SearchMode search;

      void reset() {
        candidateIndex = -1;
        candidatePrice = 0.0;
        lastExtremeIndex = -1;
        lastExtremePrice = 0.0;
        search = NONE;
      }
    };

    CAtr m_atr;
    double m_atrMultiplier;
    State m_state;

    Extreme m_extremes[];
    int m_extremeCount;
    int m_maxExtremes;

  public:
    CZigZagAdapt(int atrPeriod, double atrMultiplier, int maxExtremes = 10)
      : m_atr(atrPeriod) {
      m_atrMultiplier = atrMultiplier;
      m_maxExtremes = maxExtremes;
      m_extremeCount = 0;
      ArrayResize(m_extremes, m_maxExtremes);
      m_state.reset();
    }

    void reset(double &buff[]) {
      ArrayInitialize(buff, 0.0);
      m_state.reset();
      m_atr.reset();
      m_extremeCount = 0;
    }

    //--- Геттеры ---

    int getExtremeCount() const { return m_extremeCount; }

    // back=0 — последний, back=1 — предпоследний, ...
    bool getExtreme(int back, Extreme &ext) const {
      if (back < 0 || back >= m_extremeCount) return false;
      ext = m_extremes[m_extremeCount - 1 - back];
      return true;
    }

    SearchMode getCurrentSearch() const { return m_state.search; }
    double getCandidatePrice() const { return m_state.candidatePrice; }
    int getCandidateIndex() const { return m_state.candidateIndex; }
    double getCurrentAtr() const { return m_atr.getLastAtr(); }
    double getCurrentDeviation() const { return m_atr.getLastAtr() * m_atrMultiplier; }

    //--- Основной расчёт ---

    void calculate(double &buff[],
                   int index,
                   const double &close[],
                   const double &high[],
                   const double &low[]) {

      double atrValue = m_atr.calculate(high, low, close, index);
      double deviation = atrValue * m_atrMultiplier;

      switch (m_state.search) {
        case NONE:
          noneResolve(buff, high, low, close, index, deviation);
          break;
        case TOP:
          topResolve(buff, high, low, index, deviation);
          break;
        case BOTTOM:
          bottomResolve(buff, high, low, index, deviation);
          break;
      }
    }

  private:

    void pushExtreme(int index, double price, SearchMode type) {
      if (m_extremeCount >= m_maxExtremes) {
        for (int i = 0; i < m_maxExtremes - 1; i++) {
          m_extremes[i] = m_extremes[i + 1];
        }
        m_extremeCount = m_maxExtremes - 1;
      }
      m_extremes[m_extremeCount].index = index;
      m_extremes[m_extremeCount].price = price;
      m_extremes[m_extremeCount].type = type;
      m_extremeCount++;
    }

    void shiftCandidate(double &buff[], int newCndIndex, double newCndPrice, SearchMode mode) {
      pushExtreme(m_state.candidateIndex, m_state.candidatePrice, m_state.search);

      m_state.lastExtremeIndex = m_state.candidateIndex;
      m_state.lastExtremePrice = m_state.candidatePrice;
      m_state.candidateIndex = newCndIndex;
      m_state.candidatePrice = newCndPrice;
      buff[m_state.lastExtremeIndex] = m_state.lastExtremePrice;
      buff[m_state.candidateIndex] = m_state.candidatePrice;
      m_state.search = mode;
    }

    void updateCandidate(double &buff[], int newCndIndex, double newCndPrice) {
      buff[m_state.candidateIndex] = 0.0;
      m_state.candidateIndex = newCndIndex;
      m_state.candidatePrice = newCndPrice;
      buff[m_state.candidateIndex] = m_state.candidatePrice;
    }

    void noneResolve(double &buff[],
                     const double &high[],
                     const double &low[],
                     const double &close[],
                     int i,
                     double deviation) {

      if (m_state.candidatePrice == 0.0) {
        m_state.candidateIndex = i;
        m_state.candidatePrice = close[i];
        return;
      }

      double upDev = high[i] - m_state.candidatePrice;
      double downDev = m_state.candidatePrice - low[i];

      if (upDev > deviation && upDev >= downDev) {
        shiftCandidate(buff, i, high[i], BOTTOM);
      } else if (downDev > deviation) {
        shiftCandidate(buff, i, low[i], TOP);
      }
    }

    void bottomResolve(double &buff[],
                       const double &high[],
                       const double &low[],
                       int i,
                       double deviation) {

      if (high[i] > m_state.candidatePrice) {
        updateCandidate(buff, i, high[i]);
      }
      if (m_state.candidateIndex == i) return;

      if (m_state.candidatePrice - low[i] > deviation) {
        shiftCandidate(buff, i, low[i], TOP);
      }
    }

    void topResolve(double &buff[],
                    const double &high[],
                    const double &low[],
                    int i,
                    double deviation) {
      if (low[i] < m_state.candidatePrice) {
        updateCandidate(buff, i, low[i]);
      }
      if (m_state.candidateIndex == i) return;

      if (high[i] - m_state.candidatePrice > deviation) {
        shiftCandidate(buff, i, high[i], BOTTOM);
      }
    }
};
