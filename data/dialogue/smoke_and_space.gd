extends RefCounted
## A short authored continuation; source and scope in SMOKE_AND_SPACE_2026-11-03.md.
const ENTRY := {
	"line": "Она: Тебе весь дым в лицо.\nМожешь встать с другой стороны.",
	"choices": [
		{"label": "1. Попробую.", "reply": "Она: Посмотри, откуда дует.", "next": 1},
		{"label": "2. Мне здесь нормально.", "reply": "Она: Ладно. Я предупредила.", "next": 2},
		{"label": "3. Молчать", "reply": "Она: Если мешает — отойди.", "next": 2},
	],
}
const MOVED := {
	"line": "Она: Здесь хоть не в лицо.\nНадолго ли — не знаю.",
	"choices": [
		{"label": "1. Так нормально.", "reply": "Она: Ну и стой там.", "next": 2},
		{"label": "2. Ветер крутит.", "reply": "Она: Ага. Никак не выберет.", "next": 2},
		{"label": "3. Молчать", "reply": "Она: Ну, помолчим.", "next": 2},
	],
}
const UNMOVED := {
	"line": "Она: С этой стороны всё ещё несёт.",
	"choices": [
		{"label": "1. Так нормально.", "reply": "Она: Ладно. Как хочешь.", "next": 2},
		{"label": "2. Ветер крутит.", "reply": "Она: Ага. Никак не выберет.", "next": 2},
		{"label": "3. Молчать", "reply": "Она: Ну, помолчим.", "next": 2},
	],
}
static func page(stage: int, moved: bool) -> Dictionary:
	if stage == 0:
		return ENTRY
	return MOVED if moved else UNMOVED
