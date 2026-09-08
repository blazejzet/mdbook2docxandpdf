# book_template_md

A model, fully working source directory for `md2docx` and `md2epub` (see
`../BookToDocx`, `../BookToEpub`). Copy this directory, replace the
contents and build — every rule of the format is described below.

The governing principle of both tools: **everything a reader sees in the
book comes from the `.md` files**. No text is hardcoded in the tools or
guessed from a file name — file names serve only to establish chapter
order. The same pair of tools therefore builds a book in any language.

This file (`README.md`) is ignored by both tools — its name doesn't match
the `NN - ...` pattern, so it never enters the chapter listing.

## Try it right away

```sh
md2docx --book book_template_md -o /tmp/example.docx
md2epub --book book_template_md -o /tmp/example.epub
```

(After installing via `../install.sh`, `md2docx`/`md2epub` are on `PATH`
and the default `.docx` template is found in `~/.bookapps/templates/docx/`
on its own — there is no need to pass `--template`.)

## 1. `00 - Bookinfo.md` — metadata and the copyright page

The top of the file is plain `KEY: value` lines, in any order, blank lines
allowed:

- `TITLE` — **required**.
- `AUTHOR` — **required**.
- `SUBTITLE` — optional.
- `ISBN` — optional. It may carry text after the number (e.g.
  `9780000000000 | Independently published`) — both tools extract just the
  digits (and a possible trailing "X") wherever that is what's needed.
- `CONTENTS` — what this book calls its table of contents ("Spis treści",
  "Table of Contents"). Required by the linked-list schema below, which has
  nowhere else to put it; optional in this one, where it overrides the
  contents file's own `## ` line. Without either, the contents page is built
  with no heading and the build says so.
- `LANGUAGE` — optional but strongly recommended: a BCP 47 code (`en`,
  `pl`, `de`). It becomes the epub's `dc:language` and the `lang` attribute
  on every page. Without it the build warns and falls back to `pl`, which
  silently mislabels a book in any other language. `--lang` overrides it for
  a one-off build; the field is what survives a rebuild.
- `PRINTING DATE` (or `PRINTING_DATE`) — optional; a 4-digit year found in
  this field becomes the copyright year in the metadata. Without the field,
  the current year is used.

Below a `---` line you write **the copyright page's text exactly as it
should be printed**: one line is one centred paragraph, a blank line is a
spacer, and `**bold**` / `*italic*` work. Nothing is added by the tool
here, so formulas like "All rights reserved." or "First printing:" are in
your language and your wording:

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

The block after `---` is optional. If you leave it out, the copyright page
carries only language-neutral data: title, author, `© year author` and
`ISBN <number>`.

## 2. The contents file — two schemas

Both tools read one of **two** layouts, and pick between them by **which
starting files the directory holds**, never by looking inside them:

| Schema | Metadata file | Contents file | Chapters listed as |
|---|---|---|---|
| numbered table | `00 - Bookinfo.md` | `00 - Content.md` | a `\| Nr \| Title \| Code \|` table |
| linked list | `00_BOOKINFO.md` | `00_SPIS_TRESCI.md` or `00_CONTENTS.md` | `- [Title](file.md)` list items |

`--toc` and `--bookinfo` override the file *names* once a layout is
recognised; they do not change how the file is read. This directory is the
worked example of the first schema, `../book_template_md_linked/` of the second.

### 2a. Numbered table — `00 - Content.md`

- `## Heading` — the title of the contents page in the book's language.
  Optional here (`CONTENTS:` in bookinfo wins if both are present); at most
  one such line. It is taken neither from the file name nor from the code.
- `### Act name` opens a new "act" (a division of the book). It must appear
  at least once before the first table row.
- Markdown table rows `| Nr | Title | Code |` register chapters in the
  currently open act. The "Nr" column is matched against the leading number
  of a chapter file's name (`03 - R1 - ....md`); the "Code" column is purely
  descriptive — it is never interpreted, so you can keep your own labelling
  system in it.
- A leading `# ` line (the book title) is ignored — the metadata file is the
  single source of truth for that.

### 2b. Linked list — `00_SPIS_TRESCI.md`

- `## Part name` opens a division of the book.
- `- [Chapter 1. Title](R01_title.md) — 4029 words.` registers a chapter in
  the currently open part. The link target locates the file directly, so
  file names need no leading numbers and the order is the order you write.
  **Anything after the closing parenthesis is ignored** — word counts and
  drafting notes stay out of the book.
- **Only list items count as chapters.** A bare link in a paragraph — to
  editorial notes, a companion document — is not a chapter.
- **A `## ` section holding no chapter list items is not part of the book**
  and is skipped with a note on the console. That is what keeps a
  "manuscript status" section out of the finished text.
- A chapter file present in the directory but absent from the contents file
  is simply not in the book: the contents file decides what the book is.
- The `# ` line and any trailing prose are ignored; `CONTENTS:` in the
  metadata file supplies the contents page's heading.

### What both schemas share

**The chapter's label in the contents file is its label in the table of
contents, and only there.** The heading printed on the chapter's page comes
from the chapter file itself (see below), so the contents may carry a longer
description than the text does.

## 3. Chapter files

How a chapter file is *found* depends on the schema: the numbered-table
schema matches the "Nr" column against a name starting with a number and
`" - "` (space-hyphen-space), e.g. `03 - R1 - A Voice from Memory.md`; the
linked-list schema follows the link, so the name is entirely yours. Either
way the rest of the name is only there to read comfortably in the Finder,
and **no heading in the content is ever produced from a file name.**

The content rules below are identical in both schemas.

Rules for the file's content:

- **The first non-blank line must be `# Title`** — and that is the
  chapter's heading in the finished book.
- `## Subtitle` **directly beneath** the chapter heading produces a
  two-part heading: the top line is the `#`, the bottom one (smaller,
  italic, centred) is the `##`. Chapter
  `03 - R1 - A Voice from Memory.md` is built that way.
- `## Subheading` further into the chapter creates an ordinary centred
  subheading.
- Paragraphs are separated by a blank line. **Within one paragraph you may
  break lines freely** (soft wrapping) — adjacent lines with no blank line
  between them are joined with a single space into one paragraph (see
  `02 - U2 - The Silence of the House.md`, first paragraph).
- A line containing exactly `***` **or** `✦` (and nothing else) is a scene
  break — rendered as a centred `✦` with extra space above and below. The
  two spellings are equivalent; use whichever is easier to type.
- **Bold and italic** work inside paragraphs and headings: `**bold**`,
  `*italic*`, `***bold and italic together***` (`_underscore_` /
  `__double__` work too, but stick to one spelling throughout the book).

## 4. Cover (`md2epub` only)

A `cover.jpg` file in the book directory is detected automatically (or
point at another one with `--cover path.jpg`; `.png`, `.gif` and `.svg` are
supported too). A missing file is not an error — the epub is simply built
without a cover. The source image may be at print resolution — `md2epub`
downscales it to a sensible screen size on its own
(`--cover-max-dimension`, 2400px on the longer edge by default) and never
upscales.

## 5. The `.docx` template (`md2docx` only)

`--template` looks for the file first as given (a path relative to the
current directory, or absolute), and if it isn't there — under the same
name in `~/.bookapps/templates/docx/`. Ready-made trim sizes (5×8", 6×9"
etc.) live in `../BookToDocx/templates/` — `../install.sh` copies them all
into `~/.bookapps/templates/docx/`.
