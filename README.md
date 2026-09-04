# booksapps

Osobisty toolchain do samodzielnego wydawania książek: jedno źródło w
markdown, dwa formaty wyjściowe — `.docx` do druku (z żywą numeracją stron,
spisem treści, podziałami na akty) i `.epub` (walidowany przez
`epubcheck`, z okładką, nawigacją EPUB3 i wsteczną kompatybilnością EPUB2).

Oba narzędzia to niezależne, samodzielne pakiety Swift Package Manager —
nie mają wspólnej biblioteki. Kilka niewielkich plików parsujących (`Bo
okInfo.swift`, `Chapter.swift`, `TableOfContents.swift`, `InlineMarkdown.
swift`) jest celowo zduplikowanych w obu, żeby każde narzędzie zostało
samodzielnym plikiem wykonywalnym bez zależności między pakietami.

## Zawartość repozytorium

| Ścieżka | Co to jest |
|---|---|
| `BookToDocx/` | Pakiet SPM narzędzia `md2docx` |
| `BookToEpub/` | Pakiet SPM narzędzia `md2epub` |
| `BookToDocx/templates/` | 22 gotowe szablony `.docx` (formaty stron) |
| `book_template_md/` | Wzorcowe, działające źródło — zobacz jego `README.md` po pełny opis formatu |
| `book/` | Źródło polskiej wersji „O, Miriam” |
| `book_en/` | Źródło angielskiej wersji „Oh, Mary” |
| `install.sh` | Buduje oba narzędzia i instaluje je do `~/.bookapps` |

## Szybki start

```sh
./install.sh
```

Buduje `md2docx` i `md2epub` w trybie release, instaluje je jako
`~/.bookapps/bin/{md2docx,md2epub}`, kopiuje wszystkie szablony `.docx` do
`~/.bookapps/templates/docx/` i dopisuje `~/.bookapps/bin` do `PATH` (w
`~/.zshrc`, `~/.bash_profile` albo `~/.profile`, zależnie od `$SHELL`).
Po otwarciu nowego terminala:

```sh
md2docx --book book_template_md -o "Przykład.docx"
md2epub --book book_template_md -o "Przykład.epub"
```

Bez instalacji, bezpośrednio z repo:

```sh
swift run --package-path BookToDocx md2docx --book book_template_md -o "Przykład.docx"
swift run --package-path BookToEpub md2epub --book book_template_md -o "Przykład.epub"
```

## Format źródła

Cały tekst, który widzi czytelnik, pochodzi z plików `.md` — w kodzie
narzędzi nie ma zaszytych napisów w żadnym języku, a z nazw plików nie
powstaje żaden nagłówek (służą tylko do ustalenia kolejności rozdziałów).
Ta sama para narzędzi buduje więc książkę w dowolnym języku.

Oba narzędzia czytają ten sam układ katalogu `--book`:
- `00 - Bookinfo.md` — metadane (`TITLE`, `AUTHOR`, opcjonalnie `SUBTITLE`,
  `ISBN`, `PRINTING DATE`), a po linii `---` gotowa treść strony
  redakcyjnej, drukowana dosłownie.
- `00 - Content.md` — spis treści; nazwa pliku jest stała. `## Nagłówek`
  (wymagany, raz) to tytuł strony spisu w języku książki, `### Akt` otwiera
  dział, tabela `| Nr | Tytuł | Kod |` wylicza rozdziały. Kolumna „Tytuł”
  jest etykietą *w spisie treści*, nie nagłówkiem rozdziału.
- `NN - Kod - Tytuł.md` — po jednym pliku na rozdział, dopasowywanym do
  spisu treści po wiodącej liczbie w nazwie pliku.
- W treści rozdziału: `# Tytuł` w pierwszej linii to drukowany nagłówek
  rozdziału (a `## Podtytuł` zaraz pod nim — jego druga, mniejsza linia),
  akapity oddzielone pustą linią (miękkie zawijanie wierszy w obrębie
  akapitu jest łączone spacją), `## Śródtytuł` dalej w tekście, przerwa
  sceniczna jako `***` albo `✦` na osobnej linii, oraz inline
  `**pogrubienie**` / `*kursywa*` / `***oba naraz***` (także `_`/`__`).

Pełny, adnotowany opis każdej reguły — z przykładami — jest w
[`book_template_md/README.md`](book_template_md/README.md); ten katalog
jest też gotowym, działającym przykładem do zbudowania „na sucho”.

## `md2docx`

Buduje `.docx` odwzorowujący układ książki drukowanej: stronę tytułową,
redakcyjną, spis treści z żywymi numerami stron (pola `PAGEREF`), podziały
na akty, rozdziały z nagłówkami bieżącymi. Stylowanie (czcionki, marginesy,
motyw) kopiuje z podanego szablonu `.docx` — sam generuje tylko
`document.xml` i treść.

```
md2docx [opcje]

  --book <katalog>     Katalog z plikami rozdziałów (domyślnie: book)
  --template <plik>    Szablon .docx, z którego kopiowany jest styl
                        (domyślnie: 5.5 x 8.5 in.docx). Szukany najpierw
                        tak, jak podano (ścieżka względna albo bezwzględna),
                        a jeśli nie znaleziony — pod tą samą nazwą w
                        ~/.bookapps/templates/docx/
  --toc <plik>         Nazwa pliku spisu treści w --book
                        (domyślnie: 00 - Content.md)
  --bookinfo <plik>    Nazwa pliku metadanych w --book
                        (domyślnie: 00 - Bookinfo.md)
  --output, -o <plik>  Ścieżka wyjściowa .docx
                        (domyślnie: "<Tytuł>.docx" z bookinfo.md)
```

Szablony w `BookToDocx/templates/` (formaty stron; część w wariancie
„Endure” z gotowym stylem okładki angielskiej):
5×8", 5.06×7.81", 5.25×8", 5.5×8.5", 6×9", 6.14×9.21", 6.69×9.61", 7×10",
7.44×9.69", 7.5×9.25", 8×10", 8.25×6", 8.25×8.25", 8.25×11", 8.27×11.69",
8.5×8.5", 8.5×11".

## `md2epub`

Buduje jeden plik `.epub` (EPUB3, z `toc.ncx` dla wstecznej kompatybilności
EPUB2): stronę tytułową, redakcyjną, nawigowalny spis treści (`nav.xhtml`
pełni też rolę widocznej strony spisu), podziały na akty, rozdziały.
`mimetype` jest pierwszym wpisem archiwum i niekompresowany, zgodnie ze
specyfikacją EPUB.

```
md2epub [opcje]

  --book <katalog>     Katalog z plikami rozdziałów (domyślnie: book)
  --toc <plik>         Nazwa pliku spisu treści w --book
                        (domyślnie: 00 - Content.md)
  --bookinfo <plik>    Nazwa pliku metadanych w --book
                        (domyślnie: 00 - Bookinfo.md)
  --lang <kod>         Kod języka EPUB, np. pl, en (domyślnie: pl)
  --cover <plik>       Okładka (.jpg/.jpeg/.png/.gif/.svg). Domyślnie
                        <book>/cover.jpg — jeśli brak, epub powstaje bez
                        okładki. Zmniejszana, jeśli większa niż
                        --cover-max-dimension (nigdy nie powiększana)
  --cover-max-dimension <px>
                        Maksymalny dłuższy bok okładki rastrowej
                        (domyślnie: 2400)
  --output, -o <plik>  Ścieżka wyjściowa .epub
                        (domyślnie: "<Tytuł>.epub" z bookinfo.md)
```

Poprawność wygenerowanego pliku była weryfikowana narzędziem
[`epubcheck`](https://github.com/w3c/epubcheck) (`brew install epubcheck`).

## Wymagania

- macOS (obie zip'ują przez `/usr/bin/zip`; `md2epub` skaluje okładki
  przez `/usr/bin/sips`).
- Swift 5.9+ (Xcode Command Line Tools albo pełne Xcode).

## Rozwój

Każde narzędzie buduje się niezależnie:

```sh
swift build -c release --package-path BookToDocx
swift build -c release --package-path BookToEpub
```

Przy zmianie logiki parsowania (`BookInfo.swift`, `Chapter.swift`,
`TableOfContents.swift`, `InlineMarkdown.swift`) pamiętaj o wprowadzeniu
tej samej zmiany w obu pakietach — są duplikowane celowo, nie ma
mechanizmu, który by je synchronizował automatycznie. Po zmianach uruchom
`./install.sh` ponownie, żeby zainstalowana wersja na `PATH` była aktualna.

## Licencja

[MIT](LICENSE).
