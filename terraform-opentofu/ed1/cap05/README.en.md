# Chapter 5 — The skyscraper's datasheet

**Level:** Foundational
**Estimated time:** 45–55 minutes
**Manual topics:** what HCL is and why it exists (5.1), blocks and arguments (5.2), the primitive types (5.3), the complex types: list, map, set, object, tuple (5.4), strings, interpolation and text blocks (5.5), comments, formatting and fmt (5.6), the overview (5.7)

## The idea

Across the first four chapters you *read* HCL, guided by the comments. From
this chapter on you *write* it. No more torturing the infrastructure: this
is architect's desk work — filling in a skyscraper's technical datasheet
using, one by one, every data type in the language: the primitives for the
records, a list for the materials (where a deliberately planted duplicate
will show you the difference from a set), a map for the areas, an object
for the address, a tuple for the coordinates. Then you assemble everything
into a text block with interpolation: the datasheet itself, which the apply
deposits into a file.

The chapter closes with the humblest and most used tool of the trade: tofu
fmt, put to the test on a file written by a sloppy colleague — valid but
unreadable. You will discover what fmt always fixes (the form) and what it
never touches (the meaning).

## Goals

By the end you will be able to:

- tell at a glance a block (type, labels, body) from an argument
  (name = expression), and recognise nested blocks;
- pick the right type: list when order matters and duplicates are allowed,
  set when not; map for homogeneous keys, object for mixed structures,
  tuple for positional data;
- use the four access syntaxes: local.x, local.obj.field,
  local.map["key"], local.tuple[0];
- write a heredoc with <<-EOT and fill it with interpolations;
- use tofu fmt (-diff, -check) and state exactly what it may change and
  what it may not.

## Prerequisites

- OpenTofu (or Terraform) installed — see SETUP.md. Only the local
  provider.
- Chapters 1–4: the init/plan/apply/destroy cycle is taken for granted
  here.

## Your task

### Phase 0 — The anatomy, before writing

Open start/main.tf and read it with fresh, grammarian's eyes: everything
you see is made of two things only. *Blocks* — a type (terraform, locals,
resource, output), optional quoted labels, a body in braces — and
*arguments* — a name, an equals sign, an expression. Note the detail that
tells them apart: nested blocks (required_providers inside terraform) carry
no equals sign. That is the whole syntax: the rest of the chapter is
learning what to write *to the right of the equals signs*.

The skyscraper's records are already filled in, with the three primitives:
one string, two numbers (note: one integer, one decimal — to HCL they are
the same type), one bool.

### Phase 1 — The complex types (you write)

TODOs 1 to 4 ask you to fill in, replacing the empty placeholders:

- **TODO 1, the materials list** — laying order matters, and the foreman
  entered "steel" *twice*: keep it double, it is deliberate. Right below
  you will find a line you must not touch:
  unique_materials = toset(local.materials). It is a preview of chapter 16
  (functions): it turns your list into a set. The comparison between the
  two comes in Phase 3.
- **TODO 2, the floor-areas map** — three keys (basement, ground, tower),
  three numbers. The same shape for every value: that is what makes it a
  map.
- **TODO 3, the address object** — street (string), number (number),
  historic (bool): different types under one roof, that is what makes it
  an object.
- **TODO 4, the coordinates tuple** — latitude (number), longitude
  (number), province (string): no names, position is the meaning.

After each TODO you can run tofu validate: the file stays valid throughout,
that is what the placeholders are for.

### Phase 2 — The datasheet (interpolation and heredoc)

TODO 5 is the synthesis: the datasheet's text block. The <<-EOT syntax
opens a multi-line text (the dash lets you indent it without dirtying the
result), and inside it you plant the interpolations ${...} — one for every
access syntax:

    == ${local.name} ==
    floors     : ${local.floors}
    street     : ${local.address.street} ${local.address.number}
    ground area: ${local.floor_area["ground"]} sqm
    latitude   : ${local.coordinates[0]}
    materials  : ${join(", ", local.unique_materials)}

(join is the second and last chapter-16 preview: it glues a collection's
elements into one string.)

### Phase 3 — The apply that marks your homework

    cd start
    tofu init
    tofu apply
    cat datasheet.txt

Read the outputs carefully, because they carry the chapter's lesson:

- materials shows "steel" *twice*, in the order you wrote it: the list
  keeps everything;
- unique_materials shows it *once*, alphabetically ordered, and labelled
  toset([...]): the set threw away the duplicate and forgot the order;
- address and floor_area look alike but are no relatives: look at the
  types of the values;
- the datasheet in datasheet.txt has every value in its place.

Re-apply without changing anything: No changes, as always from here on.

### Phase 4 — The sloppy colleague (fmt)

In start/messy.tf a colleague wrote a handful of valid locals with
nightmare layout: misaligned equals signs, random indentation, stray
spaces. First look at what fmt *would* do, touching nothing:

    tofu fmt -diff -check

Then let it work:

    tofu fmt
    tofu fmt -check

Reopen the file: equals signs aligned in a column, uniform indentation. Now
the important question: what did it NOT do? It renamed nothing, reordered
no arguments, changed not a single value. fmt is a typographer, not a
copy-editor: it fixes the form, never the meaning. (Which is also why teams
put it in CI: no style debates, never a behaviour change.)

### Cleanup

    tofu destroy

## Definition of done

- tofu validate passed after each completed TODO (the file was never
  broken).
- In the outputs: "steel" appears twice in materials and once in
  unique_materials, which is alphabetically ordered and labelled toset.
- datasheet.txt contains the expected lines, with the values extracted
  from object, map and tuple through their respective access syntaxes.
- The second apply answers No changes.
- After tofu fmt, tofu fmt -check reports nothing.
- You answered the three questions in answers.md.

## The three questions

**a.** The anatomy: pick from your main.tf one example of a labelled
block, one of a nested block and one of an argument, and explain how you
recognise them (where the equals sign is, and where it is not). Then the
why: HCL exists because JSON was not enough — what did this file allow you
that in JSON would have been impossible or painful? (Think of comments,
and of what sits to the right of the equals signs.)

**b.** The types: what happened to the second "steel", and what does that
tell you about when to pick a list and when a set? By what criteria did
you decide the areas were a map and the address an object? And why does
the tuple need no field names?

**c.** Strings and form: what is the dash in <<-EOT for, and what does the
interpolation ${...} do inside the text? Then fmt: list what it changed in
the colleague's file and what it would never change — and why that
distinction (form yes, meaning no) makes it safe to run automatically in
CI.
