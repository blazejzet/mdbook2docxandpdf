# book_template_md_linked

A model, fully working source directory for the **linked-list** schema —
the same sample book as `../book_template_md/`, which is the model for the
**numbered-table** schema. Building both and comparing the results is the
quickest way to see that the two layouts are two ways of writing down the
same book.

```sh
md2docx --book book_template_md_linked -o /tmp/example-linked.docx
md2epub --book book_template_md_linked -o /tmp/example-linked.epub
```

Every rule of the format is documented in
[`../book_template_md/README.md`](../book_template_md/README.md); section 2
covers both schemas side by side. What this directory demonstrates:

- `00_BOOKINFO.md` + `00_CONTENTS.md` are the file names that select this
  schema (`00_SPIS_TRESCI.md` works in place of the latter).
- Chapter files are located by the link, so their names are free —
  `first-day.md`, not `01 - U1 - The First Day.md`.
- `CONTENTS:` in the metadata file supplies the contents page's heading;
  this schema has nowhere else to put it.
- `## Manuscript status` holds no chapter list items, so it is not a part of
  the book. The build skips it and says so on the console.
- The word counts after each link are ignored — everything after the closing
  parenthesis is drafting bookkeeping, not part of the book.
- `notes/CONTINUITY.md` is linked from a paragraph rather than a list item,
  so it is not a chapter. Only list items are.
