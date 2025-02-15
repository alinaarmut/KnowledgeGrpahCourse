# Лабораторная работа 2

Выполнил Мангараков Александр, P4241

Выполнил Большим Максим, P4240


### Выбранные стратегии

В работе для рассмотрения выбраны стратегии softmax и эпсилон-жадная.

### Обучение с помощью softmax

Использовались 4 различные значения learning rate

- 1e-2: расхождение. Модель не обучилась. Делает слишком резкие движения и сразу падает
- 1e-3: успешное обучение. Оптимальное значение для алгоритма в данных условиях. Алгоритм приводит робота в движение
- 1e-4: застревание в локальном минимуме. Модель удерживает равновесие с небольшим продвижением
- 1e-5: застревание в локальном минимуме. Модель только сохраняет равновесие

### Обучение с помощью эпсилон-жадной стратегии

В данном исследовании была использована модель DDPG с параметром sigma, принявшим значения 0.05, 0.15 и 0.3. 
При значениях 0.15 и 0.05 модель сходилась к стратегии, при которой агент старается сохранить равновесие без движения. 
Скорее всего, это объясняется тем, что даже при случайном выборе действий вероятность того, что агент выполнит действие, приводящее к продвижению вперед, крайне мала. 
При этом стратегия без риска формируется достаточно быстро. 
Также это подтверждается тем, что штраф за включение моторов для балансировки значительно меньше, чем за падение, что приводит к тому, что модель предпочитает не рисковать.
При значении 0.3 модель выбирает слишком рискованные варианты, приводящие к падению робота.

### Вывод

Среди вариантов, рассмотренных в ходе исследования, наилучший результат продемонстрировала модель SAC с learning rate, 
равным 1e-3. Остальные значения параметра либо приводили к застреванию в локальном минимуме, либо приводили к расхождению. 
Модель, основанная на эпсилон-жадной стратегии не достигла полной обучаемости, оказываясь в локальных минимумах или проявляя слишком рискованное поведение.