//+------------------------------------------------------------------+
//|                                                CZigZagAdapt.mqh  |
//|                           ZigZag с внешним deviation              |
//|                           На базе CZigZag (Albert / akhalimov)   |
//+------------------------------------------------------------------+
#property copyright "akhalimov"
#property version   "1.00"

//+------------------------------------------------------------------+
//| ZigZag с внешним deviation                                       |
//| deviation передаётся в calculate() извне — можно использовать    |
//| ATR, фиксированное значение или любой другой источник.           |
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

    State m_state;
    Extreme m_extremes[];

  public:
    CZigZagAdapt() {
      m_state.reset();
    }

    void reset(double &buff[]) {
      ArrayInitialize(buff, 0.0);
      m_state.reset();
      ArrayFree(m_extremes);
    }

    //--- Геттеры ---
    int getExtremeCount() const { return ArraySize(m_extremes); }

    void getExtremes(Extreme &dst[]) const {
      int size = ArraySize(m_extremes);
      ArrayResize(dst, size);
      for (int i = 0; i < size; i++)
        dst[i] = m_extremes[i];
    }

    SearchMode getCurrentSearch() const { return m_state.search; }
    double getCandidatePrice() const { return m_state.candidatePrice; }
    int getCandidateIndex() const { return m_state.candidateIndex; }

    //--- Основной расчёт ---

    void calculate(double &buff[],
                   int index,
                   const double &close[],
                   const double &high[],
                   const double &low[],
                   double deviation) {

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
      int size = ArraySize(m_extremes);
      ArrayResize(m_extremes, size + 1);
      m_extremes[size].index = index;
      m_extremes[size].price = price;
      m_extremes[size].type = type;
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
