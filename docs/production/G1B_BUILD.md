# G1b — Android APK и Windows EXE

Экспорт единого проекта G1a: **Godot 4.7.2 Stable Standard / GDScript**
и официальные export templates **4.7.2.stable**. Релиз движка:
https://github.com/godotengine/godot/releases/tag/4.7.2-stable
SHA-256 обоих архивов закреплены в workflow по данным официального релиза.
Сцены, скрипты, канон и предварительное разрешение 320×240 не меняются.
Compatibility и landscape уже заданы в `project.godot`.

## Экспорты и CI

- `Android Debug`: подписанный debug APK, только arm64-v8a, Android 7.0/API 24+,
  target API 36, package ID `io.github.nozomit01.invariant.debug`.
- `Windows Desktop`: debug EXE x86_64 со встроенным PCK, без подписи Windows.
- Ubuntu 24.04, Temurin JDK 17, Android SDK platform 36/build-tools 36.1.0.
  Экспорт использует готовый официальный APK-шаблон без Gradle/NDK.
- Один job импортирует проект, выполняет headless-запуск и оба экспорта из
  одного checkout. Проверяет подпись APK, ABI, package ID, landscape,
  Windows PE x86_64 и целостность ZIP; публикует SHA-256 и логи.
- Workflow `.github/workflows/g1b-build.yml` запускается на PR в `main`
  при изменении файлов проекта/экспорта и вручную через `workflow_dispatch`.
  Доступ токена: только `contents: read`; Actions закреплены по commit SHA.
- Артефакты хранятся **14 дней**: `INVARIANT-Android-debug-arm64`,
  `INVARIANT-Windows-x86_64`, `INVARIANT-build-logs`.

## Отладочная подпись и её ограничения

На каждом запуске runner создаёт **новый временный RSA debug-ключ** и случайный
пароль. Пароль маскируется в логах; Godot получает данные через переменные
окружения. Ключ находится только в runner temp, удаляется в конце job,
не загружается в артефакты/кэш и не коммитится. Репозиторные секреты не нужны.

Из-за нового сертификата **APK разных запусков нельзя обновлять друг поверх
друга** при одинаковом package ID: Android сообщит о несовпадении подписи.
Для установки следующей такой сборки нужно сначала удалить предыдущую;
это удаляет её локальные данные. Повторная установка того же APK сохраняет
его сертификат. Эти сборки — только для теста, не для магазина.

Для обновлений без удаления потребуется отдельное согласование постоянного
debug-ключа в защищённых GitHub Secrets и увеличения version/code.
Релизные ключи в этой задаче не создаются.

## Скачать APK с телефона

1. Войти в GitHub в браузере и открыть ссылку на успешный запуск из отчёта PR
   или [Actions](https://github.com/Nozomit01/Invariant/actions).
2. Открыть **G1b Android and Windows**, выбрать успешный запуск.
3. Внизу страницы в **Artifacts** нажать `INVARIANT-Android-debug-arm64`.
   Если раздел скрыт в мобильном интерфейсе, включить «Версия для ПК» в браузере.
4. Распаковать скачанный ZIP и найти `INVARIANT-debug.apk`.
   Это debug APK для Android arm64-v8a; устройства с 32-битной ОС не подходят.
5. Установку/ручной тест выполняет автор отдельно: при необходимости разрешить
   установку из данного браузера/файлового менеджера. Эта инструкция не означает,
   что G1c уже выполнена.

Windows: скачать `INVARIANT-Windows-x86_64`, распаковать артефакт и вложенный
`INVARIANT-windows-x86_64.zip`; внутри — `INVARIANT.exe` со встроенными ресурсами.
Windows-проверка на настоящем ПК остаётся отдельным ручным тестом.

## Ручной повторный запуск

После включения workflow в default branch: **Actions → G1b Android and Windows
→ Run workflow → выбрать ветку → Run workflow**. До объединения PR workflow
проверяется событием `pull_request`; ручной `workflow_dispatch` требует наличия
файла workflow в default branch по правилам GitHub. Самостоятельно PR не сливаем.

## Проверки

Локально импорт G1a выполнен официальным Godot
`4.7.2.stable.official.ed1daf0bf`: код 0, без ошибок в выводе.
После добавления пресетов локальный импорт также завершился с кодом 0,
но сообщил `Unable to open Android 'build-tools' directory.`: локально SDK
не установлен. В CI SDK установлен успешно, импорт и headless-запуск прошли.

**G1b пока не принята: APK/EXE-артефакты не созданы.**

- [PR #4](https://github.com/Nozomit01/Invariant/pull/4), ветка
  `codex/g1b-android-windows`; PR не объединён.
- [Первый запуск](https://github.com/Nozomit01/Invariant/actions/runs/39227935313):
  остановился на `setup-android`, который запросил удалённый пакет `tools`.
  Выполнена одна точечная исправляющая итерация: явно указан
  `packages: platform-tools` вместо значения action по умолчанию.
- [Второй запуск](https://github.com/Nozomit01/Invariant/actions/runs/39228056850),
  проверенный исходный коммит `813a9e12d5b517b3f1da03f04cb7b6fd0f655d2e`:
  установка SDK/JDK, проверка SHA-256 официальных архивов, импорт Godot 4.7.2
  и headless-запуск успешны. Экспорт Android завершился с кодом 1:

```text
ERROR: Cannot export project with preset "Android Debug" due to configuration errors:
"Min SDK" can only be overridden when "Use Gradle Build" is enabled.
"Target SDK" can only be overridden when "Use Gradle Build" is enabled.
ETC2/ASTC texture compression is required for Android export.
ERROR: Project export for preset "Android Debug" failed.
```

Windows-экспорт и загрузка APK/Windows ZIP были пропущены после ошибки Android.
API GitHub подтвердил только артефакт
[INVARIANT-build-logs](https://github.com/Nozomit01/Invariant/actions/runs/39228056850/artifacts/12175725937)
(1573 байта), а не готовые сборки. Чтение лога через `gh run view --log-failed`
выполнено; скачивание ZIP логов из текущего окружения получило HTTP 403.
Инструкция выше описывает скачивание будущего успешного APK, но сейчас
скачиваемого APK нет.

YAML, синтаксис shell/Python и `git diff --check` проверены локально.
`git diff --exit-code origin/main...HEAD -- project.godot scenes scripts docs/canon`
не выявил изменений игровых или канонических файлов.

Следующая исправляющая итерация и новый CI требуют отдельного разрешения:
нужно устранить указанные ограничения экспортёра (без изменения сцен и механики).
После второго неуспешного запуска код не исправлялся и CI не перезапускался;
добавлены только результаты в этот отчёт.
Успешный экспорт не доказывает запуск на телефоне или Windows-ПК.
G1c и G2 в этой задаче не выполняются.
