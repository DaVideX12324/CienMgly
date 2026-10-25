class_name QuizRpgPartyMember
extends RefCounted

## Drużyna idąca za liderem (QuizRpgPartyFollowers) dla obiektów mapy, które mają reagować na całą drużynę, nie tylko
## na gracza: animowane drzwi, płyty naciskowe, przezroczystość wysokiej trawy. Towarzysze nie są „graczem” (grupa
## player, warstwa 1), więc przejścia, skrzynie, wrogowie i zapisy zostają tylko dla lidera; mają własną warstwę
## kolizji PARTY_LAYER, a obszar, który ma ich widzieć, dokłada ją do swojej maski (watch).

const PARTY_LAYER := 128


static func is_follower(body: Node) -> bool:
	return body != null and body.get("is_party_follower") == true


## Lider albo towarzysz.
static func is_member(body: Node) -> bool:
	return body != null and (body.is_in_group("player") or body.name == "Player" or is_follower(body))


## Obszar dostaje też towarzyszy drużyny (ich ciała są na warstwie PARTY_LAYER).
static func watch(area: Area2D) -> void:
	area.collision_mask |= PARTY_LAYER
