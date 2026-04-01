# MQL5 Algorithmic Trading Project

## Обзор
Проект алгоритмической торговли на MQL5 (MetaTrader 5) + Python (бэктестинг).
Рынки: Forex, Crypto. Платформа работает через Wine на macOS.

## Структура проекта
```
Experts/My/     — торговые роботы (Expert Advisors)
Indicators/My/  — индикаторы
Scripts/My/     — скрипты
Include/My/     — библиотека классов:
  ├── Monitors/ — мониторы позиций, ордеров, счёта, символов (12 файлов)
  ├── Trade/    — торговые утилиты: MqlTradeSync, TrailingStop
  └── Utils/    — утилиты: ошибки, сортировка, MapArray, AutoPtr, DickeyFuller
Files/My/       — классы данных (CZigZag)
python/         — Python-часть (бэктестинг, анализ) [планируется]
```

### Подпапки My/Claude/
Код, сгенерированный Claude, размещается в `My/Claude/` внутри соответствующей директории по назначению:
- `Experts/My/Claude/` — торговые роботы
- `Indicators/My/Claude/` — индикаторы
- `Include/My/Claude/` — библиотечные классы
- `Scripts/My/Claude/` — скрипты
- `Files/My/Claude/` — классы данных (CAtr, CZigZagAdapt)

### Подпапки Claude/
Код, сгенерированный Claude, размещается в подпапках `My/Claude/` внутри соответствующих директорий:
```
Experts/My/Claude/     — торговые роботы
Indicators/My/Claude/  — индикаторы
Include/My/Claude/     — библиотечные классы
Scripts/My/Claude/     — скрипты
Files/My/Claude/       — классы данных
```

## Сборка и компиляция
- Компиляция выполняется внутри MetaTrader 5 (MetaEditor), не из командной строки
- Файлы .mq5 → .ex5 (компилированные), .ex5 файлы не коммитятся

## Стиль кода MQL5
- Классы в отдельных .mqh файлах, именование: CClassName
- Пользовательские файлы только в подпапках My/
- Приватные поля с префиксом m_: m_deviation, m_state
- Enum внутри классов где возможно
- Комментарии и отладочный вывод на русском языке допускаются

## Ключевые компоненты
- **SeveralBars EA** (Experts/My/) — стратегия на паттерне из одноцветных свечей
- **CZigZag** (Files/My/) — класс определения экстремумов цены (state machine)
- **CustomZigZag** (Indicators/My/) — индикатор на основе CZigZag
- **MqlTradeSync** (Include/My/Trade/) — синхронная обёртка торговых запросов
- **TradeFilter/PositionFilter** — фильтрация сделок и позиций

## Python-часть (в разработке)
- Будет в папке python/ с виртуальным окружением
- Библиотеки: pandas, numpy, vectorbt, matplotlib, jupyter
- Связь с MT5: через CSV-экспорт или API (ccxt для крипто, yfinance для Forex)

## Направление развития
- Price Action: распознавание паттернов (двойное дно, H&S, треугольники) через ZigZag
- Market Structure: BOS, CHoCH через экстремумы ZigZag
- Уровни поддержки/сопротивления: кластеризация ZigZag-точек
- Бэктестинг стратегий в Python
