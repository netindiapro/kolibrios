Утилита pe2kos написана by Rabid Rabbit и немного подправлена мной,
diamond'ом. Она используется в проектах xonix и fara (автор - Rabid Rabbit),
написанных на Visual C++, на завершающем шаге после компиляции, когда
требуется по программе в формате Windows-exe получить настоящую
Kolibri-программу. Утилита всего лишь изменяет формат exe-шника, так что,
чтобы действительно получилась работающая программа, нужно выполнение
определённых условий. Понятно, что требуется, чтобы программа общалась
с внешним миром средствами Колибри (т.е. int 0x40) и не использовала
никаких Windows-библиотек. Помимо этого, требуется также, чтобы программа
размещалась по нулевому адресу (ключ линкера "/base:0"). Как писать такие
программы - смотрите в уже упомянутых проектах xonix и fara.
Есть две версии программы, для программ, использующих путь к исполняемому
файлу (последнее слово в MENUET01-заголовке), и остальных.
Выберите нужную версию.
Использование: (в командной строке) "pe2kos <файл-источник> <файл-приёмник>".
Например, "pe2kos xonix.exe xonix".