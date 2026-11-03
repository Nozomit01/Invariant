extends RefCounted
## New dialogue written under the author's delegated creative control, 2026-11-03.
## GDD 6.2–6.3, 7, 22; Character Bible 1, 6–8, 11, 16–17. Not a source quotation.

# This single opening is quoted from GDD §6.2, unlike the authored pages below.
const SILENCE_OPENING := "Она: Чё пялишься?"

const PAGES := [
	{
		"line": "Ты: Привет. Кажется, я тебя видел.\nОна: А я тебя — нет.",
		"choices": [
			{"label": "1. Наверное, перепутал.", "reply": "Она: Бывает.", "next": 1},
			{"label": "2. Да нет, точно в этом доме.", "reply": "Она: Я сказала, что тебя не знаю.", "event": &"pressure", "next": 2},
			{"label": "3. Молчать", "reply": "Она: Ладно. Не будем угадывать.", "next": 1},
		],
	},
	{
		"line": "Она: Ты покурить пришёл?",
		"choices": [
			{"label": "1. Да. Внизу душно.", "reply": "Она: Тут зато сквозняк.\nНе знаю, что хуже.", "next": -1},
			{"label": "2. А ты?", "reply": "Она: Сейчас — курю.", "next": -1},
			{"label": "3. Молчать", "reply": "Она: Ну, стой.", "next": -1},
		],
	},
	{
		"line": "Она: Ты со мной спорить пришёл?",
		"choices": [
			{"label": "1. Нет. Просто обознался.", "reply": "Она: Ну вот. С этого бы и начал.", "next": -1},
			{"label": "2. Я просто спросил.", "reply": "Она: А я ответила.", "next": -1},
			{"label": "3. Молчать", "reply": "Она: Ладно. Проехали.", "next": -1},
		],
	},
]
