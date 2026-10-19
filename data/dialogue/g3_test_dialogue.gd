extends RefCounted
## Technical scenario data only. Button/event mappings are non-canonical.

const OPENING := "PLACEHOLDER_NON_CANON\nТехнический диалог: выберите действие."
const CHOICES := [
	{
		"label": "PLACEHOLDER_NON_CANON\n1. Ответ A",
		"reaction": "PLACEHOLDER_NON_CANON\nТест: выбран ответ A.",
	},
	{
		"label": "PLACEHOLDER_NON_CANON\n2. Ответ B",
		"reaction": "PLACEHOLDER_NON_CANON\nТест: выбран ответ B.",
	},
	{
		"label": "PLACEHOLDER_NON_CANON\n3. Молчать",
		"reaction": "PLACEHOLDER_NON_CANON\nТест: выбрано молчание.",
	},
]

# Alternate these two probes on explicit re-opening after a non-silent choice.
# Silence neither changes the hidden state nor advances the demonstration page.
const DEMOS := [
	[
		{"label": "PLACEHOLDER_NON_CANON\n1. Ответ A: чувствительная тема", "event": &"sensitive_topic"},
		{"label": "PLACEHOLDER_NON_CANON\n2. Ответ B: давление", "event": &"pressure"},
	],
	[
		{"label": "PLACEHOLDER_NON_CANON\n1. Ответ A: шаблонное поучение", "event": &"canned_advice"},
		{"label": "PLACEHOLDER_NON_CANON\n2. Ответ B: отношение как к функции", "event": &"functional_treatment"},
	],
]

const REACTIONS := {
	&"sensitive_topic": {
		&"first": "PLACEHOLDER_NON_CANON\nТест: тема вызвала настороженность.",
		&"repeated": "PLACEHOLDER_NON_CANON\nТест: повтор темы усилил напряжение.",
	},
	&"pressure": {
		&"first": "PLACEHOLDER_NON_CANON\nТест: давление вызвало протест.",
		&"repeated": "PLACEHOLDER_NON_CANON\nТест: протест против давления усилился.",
	},
	&"canned_advice": {
		&"first": "PLACEHOLDER_NON_CANON\nТест: поучение вызвало скуку.",
		&"repeated": "PLACEHOLDER_NON_CANON\nТест: внимание к поучениям снизилось.",
	},
	&"functional_treatment": {
		&"first": "PLACEHOLDER_NON_CANON\nТест: реакция стала менее выразительной.",
		&"repeated": "PLACEHOLDER_NON_CANON\nТест: реакция стала ещё суше.",
	},
}
