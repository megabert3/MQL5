//+------------------------------------------------------------------+
//|                                            CSRAgglomerative.mqh  |
//|                  Уровни S/R через агломеративную кластеризацию    |
//+------------------------------------------------------------------+
#property copyright "akhalimov"
#property version   "1.00"

#include "CSupportResistance.mqh"

//+------------------------------------------------------------------+
//| Агломеративная кластеризация (complete linkage)                  |
//| Сортируем точки по цене, сливаем соседние в пределах threshold.  |
//| threshold рекомендуется ставить = ATR × factor.                   |
//+------------------------------------------------------------------+
class CSRAgglomerative : public CSupportResistance {
  private:
    double m_threshold;
    int    m_minTouches;

  public:
    CSRAgglomerative(double threshold, int minTouches = 2) {
      m_threshold = threshold;
      m_minTouches = minTouches;
    }

    void setThreshold(double threshold) { m_threshold = threshold; }

    void calculate(const SRPoint &points[], int totalBars) override {
      ArrayFree(m_zones);

      int n = ArraySize(points);
      if (n == 0) return;

      // Сортируем индексы по цене
      int sorted[];
      ArrayResize(sorted, n);
      for (int i = 0; i < n; i++) sorted[i] = i;
      sortByPrice(points, sorted, 0, n - 1);

      // Проход по отсортированным точкам — формируем кластеры
      int clusterStart = 0;

      for (int i = 1; i <= n; i++) {
        // Complete linkage: проверяем расстояние от первой точки кластера до текущей
        bool endCluster = (i == n) ||
          (points[sorted[i]].price - points[sorted[clusterStart]].price > m_threshold);

        if (endCluster) {
          int count = i - clusterStart;
          if (count >= m_minTouches) {
            // Собираем все точки кластера
            int allIndices[];
            ArrayResize(allIndices, count);
            for (int j = 0; j < count; j++)
              allIndices[j] = sorted[clusterStart + j];

            // Оставляем только m_minTouches самых свежих (по barIndex)
            int recent[];
            takeRecent(points, allIndices, m_minTouches, recent);

            SRZone zone;
            buildZone(points, recent, totalBars, zone);
            pushZone(zone);
          }
          clusterStart = i;
        }
      }
    }

  private:
    // Из indices оставить только count самых свежих по barIndex
    void takeRecent(const SRPoint &points[], const int &indices[],
                    int count, int &result[]) {
      int total = ArraySize(indices);
      if (count >= total) {
        ArrayResize(result, total);
        for (int i = 0; i < total; i++) result[i] = indices[i];
        return;
      }

      // Копируем и сортируем по barIndex (убывание)
      int tmp[];
      ArrayResize(tmp, total);
      for (int i = 0; i < total; i++) tmp[i] = indices[i];
      sortByBar(points, tmp, 0, total - 1);

      // Берём последние count (самые свежие — в конце после сортировки по возрастанию)
      ArrayResize(result, count);
      for (int i = 0; i < count; i++)
        result[i] = tmp[total - count + i];
    }

    // Сортировка индексов по barIndex (возрастание)
    void sortByBar(const SRPoint &points[], int &idx[], int lo, int hi) {
      if (lo >= hi) return;
      int pivot = points[idx[(lo + hi) / 2]].barIndex;
      int i = lo, j = hi;
      while (i <= j) {
        while (points[idx[i]].barIndex < pivot) i++;
        while (points[idx[j]].barIndex > pivot) j--;
        if (i <= j) {
          int tmp = idx[i]; idx[i] = idx[j]; idx[j] = tmp;
          i++; j--;
        }
      }
      if (lo < j)  sortByBar(points, idx, lo, j);
      if (i < hi)  sortByBar(points, idx, i, hi);
    }

    // Быстрая сортировка индексов по цене
    void sortByPrice(const SRPoint &points[], int &idx[], int lo, int hi) {
      if (lo >= hi) return;
      double pivot = points[idx[(lo + hi) / 2]].price;
      int i = lo, j = hi;
      while (i <= j) {
        while (points[idx[i]].price < pivot) i++;
        while (points[idx[j]].price > pivot) j--;
        if (i <= j) {
          int tmp = idx[i]; idx[i] = idx[j]; idx[j] = tmp;
          i++; j--;
        }
      }
      if (lo < j)  sortByPrice(points, idx, lo, j);
      if (i < hi)  sortByPrice(points, idx, i, hi);
    }
};
