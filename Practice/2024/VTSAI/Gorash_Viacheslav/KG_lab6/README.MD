# Лабораторная работа 6

Выполнил Гораш Вячеслав, гр. P4240

### Характеристика датасета

Был выбран датесет PharmKG8k, являющийся базой знаний в области фармацевтики.
Датасет содержит 400000 триплетов в тренировочном наборе данных, 50000 в тестовом и столько же в валидационном наборах.

### Процесс обучения

Модели ComplEx и HolE обучались на 1, 20, 50 и 100 эпохах каждая. Обучение происходило на GPU. В ходе обучения несколько 
раз возникало переполнение памяти видеокарты во время валидации. Проблема решалась перезапуском процесса.

### Выводы

Из анализа метрик видно, что архитектура HolE существенно лучше показывает себя на данном датасете. Значение ROC - кривой 
достигает максимума уже на 20 эпохах. В задаче предсказания соединений данная модель также выдает более стабильный результат