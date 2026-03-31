//+------------------------------------------------------------------+
//|                                                      ZZClass.mqh |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

class CZigZag {
  public:
    enum SearchMode {
      NONE,
      TOP,
      BOTTOM
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
  
    double m_deviation;
    State m_state;
  
  public:
    CZigZag(double deviation) {
      m_deviation = deviation * _Point;
      m_state.reset();
    }

    void reset(double &buff[]) {
      ArrayInitialize(buff, 0.0);
      m_state.reset();
    }

    void shiftCandidate(double &buff[], int newCndIndex, double newCndPrice, SearchMode mode) {
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
                     int i) {

      if (m_state.candidatePrice == 0.0) {
        m_state.candidateIndex = i;
        m_state.candidatePrice = close[i];
        return;
      }

      double upDev = high[i] - m_state.candidatePrice;
      double downDev = m_state.candidatePrice - low[i];

      if (upDev > m_deviation && upDev >= downDev) {
        shiftCandidate(buff, i, high[i], BOTTOM);
      } else if (downDev > m_deviation) {
        shiftCandidate(buff, i, low[i], TOP);
      }
    }

    void bottomResolve(double &buff[],
                       const double &high[],
                       const double &low[],
                       int i) {

      if (high[i] > m_state.candidatePrice) {
        updateCandidate(buff, i, high[i]);
      }
      if (m_state.candidateIndex == i) return;

      if (m_state.candidatePrice - low[i] > m_deviation) {
        shiftCandidate(buff, i, low[i], TOP);
      }
    }

    void topResolve(double &buff[],
                    const double &high[],
                    const double &low[],
                    int i) {
      if (low[i] < m_state.candidatePrice) {
        updateCandidate(buff, i, low[i]);
      }
      if (m_state.candidateIndex == i) return;

      if (high[i] - m_state.candidatePrice > m_deviation) {
        shiftCandidate(buff, i, high[i], BOTTOM);
      }
    }

    void calculate(double &buff[],
                   int index,
                   const double &close[],
                   const double &high[],
                   const double &low[]) {
      switch (m_state.search) {
        case NONE: {
          noneResolve(buff, high, low, close, index);
        } break;
        case TOP: {
          topResolve(buff, high, low, index);
        } break;
        case BOTTOM: {
          bottomResolve(buff, high, low, index);
        } break;
      }
    }
};
