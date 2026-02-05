# STASZEK DLA STASZICA — strona statyczna

To jest w 100% statyczna strona (HTML/CSS/JS).

## Jak uruchomić lokalnie

Najprościej przez lokalny serwer (żeby wszystko działało tak samo jak na hostingu):

```bash
python3 -m http.server 8000
```

Potem wejdź w przeglądarce na `http://localhost:8000`.

## Jak dodać nowe posty (Aktualności)

Edytuj `data/content.js` → tablica `news`.

Każdy post ma pola:
- `title`
- `date` (opcjonalnie)
- `image` (opcjonalnie; ścieżka do pliku w `zdjęcia/`)
- `tags` (opcjonalnie)
- `body`

## Jak dodać nowe plakaty

Edytuj `data/content.js` → `images.posters`.
