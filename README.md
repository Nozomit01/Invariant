# INVARIANT / «Крыша» — Codex Preproduction Kit V4

**Состояние на 19.10.2026:** этап 0 — документация и техническое проектирование. **Это не игровой проект, сборок нет.**

**Репозиторий:** https://github.com/Nozomit01/Invariant (`Nozomit01/Invariant`). Старый `Nozomit01/rooftop-game` не изменять, не использовать как основу, ничего из него автоматически не мигрировать.

## Начинать отсюда

1. Открой `docs/canon/Крыша_GDD_v0.2_2D.md` (полный исходный GDD без переписывания) и `docs/canon/Character_Bible_v1.md` (полная актуальная библия героини).
2. Прочти `docs/production/DECISIONS_2026-10-19.md` — новые решения, **не внесённые** в оригинальный GDD.
3. Прочти `docs/production/CANON_AND_OPEN_QUESTIONS.md` — иерархия источников, конфликтные места и вопросы на утверждение.
4. Просмотри `docs/production/ARCHITECTURE_PROPOSAL.md`, `docs/production/ROADMAP.md`, `steam/RELEASE_PLAN.md`.
5. `AGENTS.md` задаёт ограничения Codex. Пока не согласовано завершение этапа 0, не создавать игровой код, Godot-проект, сцены, CI, Steam-загрузчики.
6. Передать документы в GitHub или Codex по `IMPORT_GUIDE.md`; сам ZIP недоступен Codex до импорта.
7. Начинать взаимодействие с Codex с `prompts/001_REVIEW_DOCS_ONLY.md`.

## Почему V4

V3 не включал исходные GDD и Character Bible и преждевременно поручал Codex писать код. V4 устраняет оба нарушения: **оригинальные документы включены целиком и без правок**, проектирование сначала, реализация только после отдельного разрешения автора.

## Файлы

- `AGENTS.md` — обязательные инструкции Codex.
- `IMPORT_GUIDE.md`, `CONNECTIONS.md` — практическая установка и подключения.
- `docs/canon/*` — канонические исходники.
- `docs/production/DECISIONS_2026-10-19.md` — новые решения и предложенные изменения масштаба демо.
- `docs/production/CANON_AND_OPEN_QUESTIONS.md` — иерархия документов + вопросы, которые Codex не имеет права решать самостоятельно.
- `docs/production/ARCHITECTURE_PROPOSAL.md` — предложение для обсуждения, **не реализовано**.
- `docs/production/ROADMAP.md` — последовательный план от этапа 0 до возможного релиза демо.
- `docs/production/DEMO_SCOPE.md` — предложение объёма демоверсии, отложенная функциональность.
- `docs/production/REVIEW_CHECKLIST.md` — приёмка документов и критерии допуска к программированию.
- `steam/RELEASE_PLAN.md` — Steamworks, сроки и ручные подтверждения.
- `steam/STORE_AND_RIGHTS.md` — страница Steam и права на активы.
- `assets/ASSET_REGISTER.md` — исходники/статусы/права, без придуманной доступности файлов.
- `prompts/001_REVIEW_DOCS_ONLY.md` — **первая задача Codex**, чтение и отчёт.
- `prompts/002_DESIGN_REVIEW_ONLY.md` — финальное проектирование без кодинга.
- `prompts/003_IMPLEMENTATION_ONLY_AFTER_APPROVAL.md` — шаблон на будущее, **пока не запускать**.
- `templates/TASK_TEMPLATE.md` — шаблон маленьких задач с лимитом объёма.

Пакет подготовлен локально. Он не загружен в GitHub и не создаёт платных подписок или интеграций.
