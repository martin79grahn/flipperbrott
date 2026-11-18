# Flipperbrott

Ett eget spel gjort i Godot 4.5 som blandar tegelkrossare och flipperspel. All grafik ritas i kod,
och ljud och musik skapas av `tools/make_sounds.py`.

- **Tegel:** högst upp sitter en mur av tegel. Vanliga stenar går sönder direkt, silverstenar tål flera träffar
  och guldstenar går inte sönder alls. När bara guld är kvar är banan klar och du får bonus.
- **Paddel:** en paddel mitt på bordet skickar upp kulan igen. Var på paddeln kulan träffar avgör vinkeln.
  Kulan kan passera paddeln underifrån.
- **Flipperbord:** missar du med paddeln finns det två flippers, slangbågar och bumpers längre ned. Kulan skjuts
  ut med en fjäder i rännan till höger. De första sekunderna efter utskjutet räddas kulan om den åker ut.
- **Lampor:** fyra lampor sitter i gångarna vid flipprarna. Tänd alla fyra så går multiplikatorn upp (högst x5).
  Flipperknapparna flyttar runt lamporna.
- **Kapslar** faller ibland ur krossade stenar. Ta dem med paddeln eller kulan:
  M multiboll, B bred paddel, E eldboll (går rakt igenom stenar), L laser, S skydd över utgången, + extra kula.
- Efter åtta handgjorda banor kommer slumpade banor som blir svårare. Rekordet sparas.

## Styrning

| | Tangentbord / mus | Handkontroll | Pekskärm |
|---|---|---|---|
| Paddel | ← → eller A D, eller musen | Styrkors / vänster spak | Dra med fingret på mitten av skärmen |
| Vänster flipper | Z, Skift eller Ctrl, vänster musknapp | LB / LT / X | Nedersta delen, vänster sida |
| Höger flipper | X, punkt, minus eller Alt, höger musknapp | RB / RT / B | Nedersta delen, höger sida |
| Skjut ut kulan | Håll in Mellanslag, ↓ eller en flipper och släpp | A | Håll in en flipper och släpp |
| Paus | Esc eller P | Start | II |
| Ljud av/på | M | | i menyn |

## Bygga

```
python3 tools/make_sounds.py
godot --headless --export-release "Linux" export/linux/Flipperbrott.x86_64
godot --headless --export-release "Android" export/Flipperbrott.apk
```

Android-nyckeln ligger utanför repot och anges med miljövariablerna `GODOT_ANDROID_KEYSTORE_RELEASE_PATH`,
`GODOT_ANDROID_KEYSTORE_RELEASE_USER` och `GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD`.
