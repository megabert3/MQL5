---
name: feedback-claude-subdirs
description: Claude-generated code goes into My/Claude/ subdirectories, matching the parent directory purpose
type: feedback
---

Код от Claude размещать в подпапках My/Claude/ по назначению (Experts/My/Claude/, Indicators/My/Claude/ и т.д.), а не в отдельной общей папке.

**Why:** Альберт хочет чётко отделять свой код от сгенерированного, при этом сохраняя логику размещения по типу файла.

**How to apply:** При создании любого .mqh/.mq5 файла — определить тип (EA, индикатор, библиотека, скрипт, данные) и положить в соответствующую директорию My/Claude/. Также выделять переиспользуемые компоненты в отдельные классы (например CAtr отдельно от CZigZagAdapt).
