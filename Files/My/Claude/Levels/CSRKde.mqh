//+------------------------------------------------------------------+
//|                                                     CSRKde.mqh   |
//|                  Уровни S/R через Kernel Density Estimation       |
//+------------------------------------------------------------------+
#property copyright "akhalimov"
#property version   "1.00"

#include "CSupportResistance.mqh"

//+------------------------------------------------------------------+
//| KDE: строим кривую плотности по ценам экстремумов,              |
//| локальные максимумы кривой = уровни S/R.                         |
//| bandwidth рекомендуется ставить = ATR × factor.                   |
//+------------------------------------------------------------------+
class CSRKde : public CSupportResistance {
  private:
    double m_bandwidth;
    int    m_steps;       // кол-во точек сканирования
    double m_minDensity;  // минимальная плотность для уровня

  public:
    CSRKde(double bandwidth, int steps = 200, double minDensity = 0.5) {
      m_bandwidth = bandwidth;
      m_steps = steps;
      m_minDensity = minDensity;
    }

    void setBandwidth(double bandwidth) { m_bandwidth = bandwidth; }

    void calculate(const SRPoint &points[], int totalBars) override {
      ArrayFree(m_zones);

      int n = ArraySize(points);
      if (n < 2) return;

      // Определяем диапазон цен
      double minPrice = points[0].price;
      double maxPrice = points[0].price;
      for (int i = 1; i < n; i++) {
        if (points[i].price < minPrice) minPrice = points[i].price;
        if (points[i].price > maxPrice) maxPrice = points[i].price;
      }

      double range = maxPrice - minPrice;
      if (range <= 0) return;

      double step = range / m_steps;

      // Считаем плотность для каждой точки сетки
      double density[];
      double prices[];
      ArrayResize(density, m_steps + 1);
      ArrayResize(prices, m_steps + 1);

      for (int s = 0; s <= m_steps; s++) {
        prices[s] = minPrice + s * step;
        density[s] = 0.0;

        for (int i = 0; i < n; i++) {
          double u = (prices[s] - points[i].price) / m_bandwidth;
          density[s] += gaussianKernel(u);
        }
        density[s] /= (n * m_bandwidth);
      }

      // Ищем локальные максимумы
      for (int s = 1; s < m_steps; s++) {
        if (density[s] > density[s - 1] &&
            density[s] > density[s + 1] &&
            density[s] >= m_minDensity) {

          double peakPrice = prices[s];

          // Собираем точки, попавшие в окрестность bandwidth от пика
          int indices[];
          int count = 0;
          for (int i = 0; i < n; i++) {
            if (MathAbs(points[i].price - peakPrice) <= m_bandwidth) {
              ArrayResize(indices, count + 1);
              indices[count] = i;
              count++;
            }
          }

          if (count >= 2) {
            SRZone zone;
            buildZone(points, indices, totalBars, zone);
            zone.score *= density[s]; // усиливаем score плотностью
            pushZone(zone);
          }
        }
      }
    }

  private:
    // Гауссово ядро: K(u) = (1/√2π) × exp(-u²/2)
    double gaussianKernel(double u) {
      return MathExp(-0.5 * u * u) / 2.5066282746; // 2.5066.. = √(2π)
    }
};
