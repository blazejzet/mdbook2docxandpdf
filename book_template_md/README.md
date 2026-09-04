# book_template_md

Wzorcowy, w pełni działający katalog źródłowy dla `md2docx` i `md2epub`
(patrz `../BookToDocx`, `../BookToEpub`). Skopiuj ten katalog, podmień
zawartość i zbuduj — poniżej opis każdej reguły formatu.

Ten plik (`README.md`) jest ignorowany przez oba narzędzia — nie ma w nazwie
wzorca `NN - ...`, więc nigdy nie trafia do spisu rozdziałów.

## Wypróbuj od razu

```sh
md2docx --book book_template_md -o /tmp/przyklad.docx
md2epub --book book_template_md -o /tmp/przyklad.epub
```

(Po instalacji przez `../install.sh` `md2docx`/`md2epub` są na `PATH`, a
domyślny szablon `.docx` sam znajdzie się w `~/.bookapps/templates/docx/` —
nie trzeba podawać `--template`.)

## 1. `00 - Bookinfo.md` — metadane

Proste linie `KLUCZ: wartość`, w dowolnej kolejności, puste linie dozwolone:

- `TITLE` — **wymagane**.
- `AUTHOR` — **wymagane**.
- `SUBTITLE` — opcjonalne.
- `ISBN` — opcjonalne. Może zawierać tekst po numerze (np.
  `9780000000000 | Independently published`) — oba narzędzia same wyciągają
  z tego same cyfry (i ewentualne końcowe „X”) tam, gdzie to potrzebne.
- `PRINTING DATE` (albo `PRINTING_DATE`) — opcjonalne; sam 4-cyfrowy rok w
  tym polu trafia na stronę redakcyjną jako rok praw autorskich. Bez tego
  pola użyty zostanie bieżący rok.

## 2. `00 - Spis treści.md` — spis treści

- `### Nazwa aktu` otwiera nowy „akt” (dział książki). Musi wystąpić co
  najmniej raz przed pierwszym wierszem tabeli.
- Wiersze tabeli markdown `| Nr | Tytuł | Kod |` rejestrują rozdziały w
  aktualnie otwartym akcie. Kolumna „Kod” jest czysto opisowa — nie jest
  nigdzie interpretowana, możesz w niej trzymać własny system oznaczeń.
- **To ten plik, nie plik rozdziału, jest źródłem prawdy dla tytułu
  rozdziału** — pierwszy nagłówek `#` w pliku rozdziału służy tylko do
  sprawdzenia poprawności pliku i nigdy nie trafia do wyniku.
- Tytuł zawierający em dash otoczony spacjami (`Tytuł — Podtytuł`) tworzy
  dwuczęściowy nagłówek: górna linia to `Tytuł`, dolna (mniejsza,
  wyśrodkowana) to `Podtytuł`. W tym przykładzie użyte dla rozdziału
  „ACCOUNT I — A Voice from Memory”.

## 3. Pliki rozdziałów — `NN - Kod - Tytuł.md`

Nazwa pliku musi zaczynać się od liczby i `" - "` (spacja-myślnik-spacja);
ta liczba musi zgadzać się z kolumną „Nr” w spisie treści — reszta nazwy
pliku jest dowolna i tylko dla wygody czytania w Finderze.

Zasady treści pliku:

- **Pierwsza niepusta linia musi być `# Tytuł`.** Jak wyżej — to tylko
  kontrola poprawności pliku, sam tekst nigdy nie trafia do wyniku (o
  prawdziwym tytule decyduje spis treści).
- Akapity oddziela pusta linia. **W obrębie jednego akapitu możesz łamać
  wiersze dowolnie** (miękkie zawijanie) — sąsiednie linie bez pustej linii
  między nimi zostaną złączone jedną spacją w jeden akapit (patrz
  `02 - U2 - The Silence of the House.md`, pierwszy akapit).
- `## Śródtytuł` w środku rozdziału tworzy wyśrodkowany podnagłówek.
- Linia zawierająca dokładnie `***` **albo** `✦` (i nic więcej) to przerwa
  sceniczna — w wyniku wyśrodkowany `✦` z dodatkowym odstępem nad i pod.
  Oba zapisy są równoważne, użyj tego, który wygodniej się pisze.
- **Pogrubienie i kursywa** działają wewnątrz akapitów i śródtytułów:
  `**pogrubienie**`, `*kursywa*`, `***pogrubienie i kursywa razem***`
  (`_podkreślnik_` / `__podwójny__` też działają, ale konsekwentnie trzymaj
  się jednego zapisu w całej książce).

## 4. Okładka (tylko `md2epub`)

Plik `cover.jpg` w katalogu książki jest wykrywany automatycznie (albo
wskaż inny przez `--cover ścieżka.jpg`; obsługiwane są też `.png`, `.gif`,
`.svg`). Brak pliku nie jest błędem — epub po prostu powstanie bez okładki.
Źródłowy obraz może być w rozdzielczości do druku — `md2epub` sam go
zmniejszy do rozsądnego rozmiaru ekranowego (`--cover-max-dimension`,
domyślnie 2400px na dłuższym boku), nigdy nie powiększa.

## 5. Szablon `.docx` (tylko `md2docx`)

`--template` szuka pliku najpierw tak, jak podano (ścieżka względna do
bieżącego katalogu albo bezwzględna), a jeśli go tam nie ma — pod tą samą
nazwą w `~/.bookapps/templates/docx/`. Gotowe formaty stron (5×8", 6×9" itd.)
są w `../BookToDocx/templates/` — `../install.sh` kopiuje je wszystkie do
`~/.bookapps/templates/docx/`.
