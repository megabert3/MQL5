//+------------------------------------------------------------------+
//|                                                  CSRDbscan.mqh   |
//|                  Уровни S/R через DBSCAN кластеризацию           |
//+------------------------------------------------------------------+
#property copyright "akhalimov"
#property version   "1.00"

#include "CSupportResistance.mqh"

//+------------------------------------------------------------------+
//| DBSCAN: группирует плотные скопления экстремумов,               |
//| одиночные точки автоматически отбрасываются как шум.             |
//| eps рекомендуется ставить = ATR × factor.                        |
//+------------------------------------------------------------------+
class CSRDbscan : public CSupportResistance {
  private:
    double m_eps;
    int    m_minSamples;

  public:
    CSRDbscan(double eps, int minSamples = 2) {
      m_eps = eps;
      m_minSamples = minSamples;
    }

    void setEps(double eps) { m_eps = eps; }

    void calculate(const SRPoint &points[], int totalBars) override {
      ArrayFree(m_zones);

      int n = ArraySize(points);
      if (n == 0) return;

      // Метки: -1 = не посещена, 0 = шум, >0 = номер кластера
      int labels[];
      ArrayResize(labels, n);
      ArrayInitialize(labels, -1);

      int clusterId = 0;

      for (int i = 0; i < n; i++) {
        if (labels[i] != -1) continue;

        // Находим соседей точки i
        int neighbors[];
        findNeighbors(points, i, n, neighbors);

        if (ArraySize(neighbors) < m_minSamples) {
          labels[i] = 0; // шум
          continue;
        }

        // Новый кластер
        clusterId++;
        labels[i] = clusterId;

        // Очередь для расширения кластера
        int queue[];
        int qSize = ArraySize(neighbors);
        ArrayResize(queue, qSize);
        for (int j = 0; j < qSize; j++) queue[j] = neighbors[j];

        int qHead = 0;
        while (qHead < qSize) {
          int qi = queue[qHead];
          qHead++;

          if (labels[qi] == 0)
            labels[qi] = clusterId; // шум → граничная точка

          if (labels[qi] != -1) continue;

          labels[qi] = clusterId;

          // Ищем соседей qi
          int qNeighbors[];
          findNeighbors(points, qi, n, qNeighbors);

          if (ArraySize(qNeighbors) >= m_minSamples) {
            // Добавляем новых соседей в очередь
            for (int j = 0; j < ArraySize(qNeighbors); j++) {
              ArrayResize(queue, qSize + 1);
              queue[qSize] = qNeighbors[j];
              qSize++;
            }
          }
        }
      }

      // Собираем кластеры в зоны
      for (int c = 1; c <= clusterId; c++) {
        int indices[];
        int count = 0;
        for (int i = 0; i < n; i++) {
          if (labels[i] == c) {
            ArrayResize(indices, count + 1);
            indices[count] = i;
            count++;
          }
        }

        SRZone zone;
        buildZone(points, indices, totalBars, zone);
        pushZone(zone);
      }
    }

  private:
    // Найти все точки в радиусе eps от points[idx]
    void findNeighbors(const SRPoint &points[], int idx, int n, int &result[]) {
      ArrayFree(result);
      int count = 0;
      for (int i = 0; i < n; i++) {
        if (i == idx) continue;
        if (MathAbs(points[i].price - points[idx].price) <= m_eps) {
          ArrayResize(result, count + 1);
          result[count] = i;
          count++;
        }
      }
    }
};
