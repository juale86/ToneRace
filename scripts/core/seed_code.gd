class_name SeedCode
extends RefCounted
## Códigos de pista de 6 caracteres, sin caracteres ambiguos (0/O, 1/I/L).

const ALPHABET := "23456789ABCDEFGHJKMNPQRSTUVWXYZ"
const LENGTH := 6
const COUNT := 887503681  # 31^6


static func encode(value: int) -> String:
	var base := ALPHABET.length()
	value = posmod(value, COUNT)
	var code := ""
	for i in LENGTH:
		code = ALPHABET[value % base] + code
		value /= base
	return code


## Devuelve -1 si el código no es válido. Acepta minúsculas y espacios alrededor.
static func decode(code: String) -> int:
	code = code.strip_edges().to_upper()
	if code.length() != LENGTH:
		return -1
	var value := 0
	for c in code:
		var digit := ALPHABET.find(c)
		if digit == -1:
			return -1
		value = value * ALPHABET.length() + digit
	return value


static func random() -> int:
	return randi() % COUNT
