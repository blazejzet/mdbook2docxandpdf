# booksapps

A personal self-publishing toolchain: one markdown source, two output
formats — `.docx` for print (live page numbers, table of contents, act
dividers) and `.epub` (validated with `epubcheck`, with a cover, EPUB3
navigation and EPUB2 backwards compatibility).

Both tools are independent, self-contained Swift Package Manager packages —
there is no shared library. A few small parsing files (`BookInfo.swift`,
`Chapter.swift`, `TableOfContents.swift`, `InlineMarkdown.swift`) are
duplicated in both on purpose, so that each tool stays a standalone
executable with no dependency between the packages.

## Repository contents

| Path | What it is |
|---|---|
| `BookToDocx/` | SPM package for the `md2docx` tool |
| `BookToEpub/` | SPM package for the `md2epub` tool |
| `BookToDocx/templates/` | 22 ready-made `.docx` templates (trim sizes) |
| `book_template_md/` | A model, working source directory — see its `README.md` for the full format description |
| `install.sh` | Builds both tools and installs them into `~/.bookapps` |

## Quick start

```sh
./install.sh
```

Builds `md2docx` and `md2epub` in release mode, installs them as
`~/.bookapps/bin/{md2docx,md2epub}`, copies every `.docx` template into
`~/.bookapps/templates/docx/`, and appends `~/.bookapps/bin` to `PATH` (in
`~/.zshrc`, `~/.bash_profile` or `~/.profile`, depending on `$SHELL`).
Once you open a new terminal:

```sh
md2docx --book book_template_md -o "Example.docx"
md2epub --book book_template_md -o "Example.epub"
```

Without installing, straight from the repo:

```sh
swift run --package-path BookToDocx md2docx --book book_template_md -o "Example.docx"
swift run --package-path BookToEpub md2epub --book book_template_md -o "Example.epub"
```

## Source format

Every word a reader sees comes from the `.md` files — no string in any
language is hardcoded in the tools, and no heading is ever derived from a
file name (file names only establish chapter order). The same pair of tools
therefore builds a book in any language.

Both tools read the same `--book` directory layout:
- `00 - Bookinfo.md` — metadata (`TITLE`, `AUTHOR`, optionally `SUBTITLE`,
  `ISBN`, `PRINTING DATE`), and below a `---` line the finished text of the
  copyright page, printed verbatim.
- `00 - Content.md` — the table of contents; the file name is fixed.
  `## Heading` (required, once) is the title of the contents page in the
  book's own language, `### Act` opens a division, and the
  `| Nr | Title | Code |` table lists the chapters. The "Title" column is a
  label *in the table of contents*, not the chapter's heading.
- `NN - Code - Title.md` — one file per chapter, matched to the table of
  contents by the leading number in the file name.
- Inside a chapter: `# Title` on the first line is the chapter heading as
  printed (and `## Subtitle` directly beneath it becomes its second,
  smaller line); paragraphs separated by a blank line (soft-wrapped lines
  within one paragraph are joined with a space); `## Subheading` further
  into the text; a scene break as `***` or `✦` on a line of its own; and
  inline `**bold**` / `*italic*` / `***both at once***` (`_`/`__` too).

The full annotated description of every rule — with examples — is in
[`book_template_md/README.md`](book_template_md/README.md); that directory
is also a ready, working example to build as a dry run.

## `md2docx`

Builds a `.docx` that mirrors the layout of a printed book: title page,
copyright page, table of contents with live page numbers (`PAGEREF`
fields), act dividers, chapters with running heads. Styling (fonts,
margins, theme) is copied from the given `.docx` template — the tool itself
generates only `document.xml` and the content.

```
md2docx [options]

  --book <dir>         Directory with chapter files (default: book)
  --template <file>    Template .docx to copy styling from
                        (default: 5.5 x 8.5 in.docx). Resolved first as
                        given (relative or absolute path), and if not found
                        there — under the same name in
                        ~/.bookapps/templates/docx/
  --toc <file>         Contents file name inside --book
                        (default: 00 - Content.md)
  --bookinfo <file>    Metadata file name inside --book
                        (default: 00 - Bookinfo.md)
  --output, -o <file>  Output .docx path
                        (default: "<Title>.docx" from bookinfo.md)
```

Templates in `BookToDocx/templates/` (trim sizes; some in an "Endure"
variant carrying a ready-made English cover style):
5×8", 5.06×7.81", 5.25×8", 5.5×8.5", 6×9", 6.14×9.21", 6.69×9.61", 7×10",
7.44×9.69", 7.5×9.25", 8×10", 8.25×6", 8.25×8.25", 8.25×11", 8.27×11.69",
8.5×8.5", 8.5×11".

## `md2epub`

Builds a single `.epub` file (EPUB3, with a `toc.ncx` for EPUB2 backwards
compatibility): title page, copyright page, a navigable table of contents
(`nav.xhtml` doubles as the visible contents page), act dividers, chapters.
`mimetype` is the first entry in the archive and uncompressed, as the EPUB
specification requires.

```
md2epub [options]

  --book <dir>         Directory with chapter files (default: book)
  --toc <file>         Contents file name inside --book
                        (default: 00 - Content.md)
  --bookinfo <file>    Metadata file name inside --book
                        (default: 00 - Bookinfo.md)
  --lang <code>        EPUB language code, e.g. pl, en (default: pl)
  --cover <file>       Cover (.jpg/.jpeg/.png/.gif/.svg). Defaults to
                        <book>/cover.jpg — if absent, the epub is built
                        without one. Downscaled if larger than
                        --cover-max-dimension (never upscaled)
  --cover-max-dimension <px>
                        Longest edge a raster cover is downscaled to
                        (default: 2400)
  --output, -o <file>  Output .epub path
                        (default: "<Title>.epub" from bookinfo.md)
```

The generated file has been verified with
[`epubcheck`](https://github.com/w3c/epubcheck) (`brew install epubcheck`).

## Requirements

- macOS (both zip through `/usr/bin/zip`; `md2epub` scales covers through
  `/usr/bin/sips`).
- Swift 5.9+ (Xcode Command Line Tools or full Xcode).

## Development

Each tool builds independently:

```sh
swift build -c release --package-path BookToDocx
swift build -c release --package-path BookToEpub
```

When changing parsing logic (`BookInfo.swift`, `Chapter.swift`,
`TableOfContents.swift`, `InlineMarkdown.swift`), remember to make the same
change in both packages — they are duplicated on purpose and nothing keeps
them in sync automatically. After any change, run `./install.sh` again so
that the version installed on `PATH` is up to date.

## License

[MIT](LICENSE).
