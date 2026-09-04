# book_template_md

Wzorcowy, w pełni działający katalog źródłowy dla `md2docx` i `md2epub`
(patrz `../BookToDocx`, `../BookToEpub`). Skopiuj ten katalog, podmień
zawartość i zbuduj — poniżej opis każdej reguły formatu.

Zasada nadrzędna obu narzędzi: **wszystko, co czytelnik zobaczy w książce,
pochodzi z plików `.md`**. Żaden tekst nie jest zaszyty w kodzie ani
zgadywany z nazwy pliku — nazwy plików służą wyłącznie do ustalenia
kolejności rozdziałów. Dzięki temu ta sama para narzędzi buduje książkę w
dowolnym języku.

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

## 1. `00 - Bookinfo.md` — metadane i strona redakcyjna

Górna część pliku to proste linie `KLUCZ: wartość`, w dowolnej kolejności,
puste linie dozwolone:

- `TITLE` — **wymagane**.
- `AUTHOR` — **wymagane**.
- `SUBTITLE` — opcjonalne.
- `ISBN` — opcjonalne. Może zawierać tekst po numerze (np.
  `9780000000000 | Independently published`) — oba narzędzia same wyciągają
  z tego same cyfry (i ewentualne końcowe „X”) tam, gdzie to potrzebne.
- `PRINTING DATE` (albo `PRINTING_DATE`) — opcjonalne; sam 4-cyfrowy rok w
  tym polu trafia do metadanych jako rok praw autorskich. Bez tego pola
  użyty zostanie bieżący rok.

Poniżej linii `---` piszesz **treść strony redakcyjnej — dokładnie tak, jak
ma się wydrukować**: jedna linia to jeden wyśrodkowany akapit, pusta linia
to odstęp, działa `**pogrubienie**` / `*kursywa*`. Nic tu nie jest
dopisywane przez narzędzie, więc formuły w rodzaju „Wszelkie prawa
zastrzeżone.” czy „Wydanie pierwsze:” są w Twoim języku i Twoim brzmieniu:

```
PRINTING DATE: 01.2027

---

Sample Title
First Last

Copyright © 2027 First Last
All rights reserved.

ISBN 9780000000000

First printing: 01.2027
```

Blok po `---` jest opcjonalny. Jeśli go pominiesz, strona redakcyjna
zawiera tylko dane językowo neutralne: tytuł, autora, `© rok autor` oraz
`ISBN <numer>`.

## 2. `00 - Content.md` — spis treści

Nazwa tego pliku jest stała: **zawsze `00 - Content.md`** (można ją zmienić
przez `--toc`, ale nie ma po temu powodu).

- `## Nagłówek` — **wymagane, dokładnie raz**. To tytuł strony spisu treści
  w języku książki („Spis treści”, „Table of Contents”, …). Trafia na
  stronę spisu w `.docx` i na `nav.xhtml` w `.epub`. Nie jest brany ani z
  nazwy pliku, ani z kodu narzędzia.
- `### Nazwa aktu` otwiera nowy „akt” (dział książki). Musi wystąpić co
  najmniej raz przed pierwszym wierszem tabeli.
- Wiersze tabeli markdown `| Nr | Tytuł | Kod |` rejestrują rozdziały w
  aktualnie otwartym akcie. Kolumna „Nr” wiąże wiersz z plikiem rozdziału,
  kolumna „Kod” jest czysto opisowa — nie jest nigdzie interpretowana,
  możesz w niej trzymać własny system oznaczeń.
- **Kolumna „Tytuł” jest etykietą rozdziału w spisie treści i tylko tam.**
  Nagłówek drukowany na stronie rozdziału bierze się z samego pliku
  rozdziału (patrz niżej), więc w spisie możesz mieć dłuższy opis niż w
  treści — jak tutaj „ACCOUNT I — A Voice from Memory” dla rozdziału,
  którego strona zaczyna się od „ACCOUNT I”.
- Wiodąca linia `# ` (tytuł książki) jest ignorowana — źródłem prawdy dla
  metadanych jest `00 - Bookinfo.md`.

## 3. Pliki rozdziałów — `NN - Kod - Tytuł.md`

Nazwa pliku musi zaczynać się od liczby i `" - "` (spacja-myślnik-spacja);
ta liczba musi zgadzać się z kolumną „Nr” w spisie treści — reszta nazwy
pliku jest dowolna i tylko dla wygody czytania w Finderze. **Z nazwy pliku
nigdy nie powstaje żaden nagłówek w treści.**

Zasady treści pliku:

- **Pierwsza niepusta linia musi być `# Tytuł`** — i to ona jest nagłówkiem
  rozdziału w gotowej książce.
- `## Podtytuł` **bezpośrednio pod** nagłówkiem rozdziału daje
  dwuczęściowy nagłówek: górna linia to `#`, dolna (mniejsza, kursywą,
  wyśrodkowana) to `##`. Tak zrobiony jest rozdział
  `03 - R1 - A Voice from Memory.md`.
- `## Śródtytuł` w dalszej części rozdziału tworzy zwykły wyśrodkowany
  podnagłówek.
- Akapity oddziela pusta linia. **W obrębie jednego akapitu możesz łamać
  wiersze dowolnie** (miękkie zawijanie) — sąsiednie linie bez pustej linii
  między nimi zostaną złączone jedną spacją w jeden akapit (patrz
  `02 - U2 - The Silence of the House.md`, pierwszy akapit).
- Linia zawierająca dokładnie `***` **albo** `✦` (i nic więcej) to przerwa
  sceniczna — w wyniku wyśrodkowany `✦` z dodatkowym odstępem nad i pod.
  Oba zapisy są równoważne, użyj tego, który wygodniej się pisze.
- **Pogrubienie i kursywa** działają wewnątrz akapitów i nagłówków:
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
