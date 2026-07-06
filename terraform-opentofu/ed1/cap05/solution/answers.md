# Chapter 5 — Answers (model solution)

## The list and the set (Phase 3)

    materials = [
      "steel",
      "glass",
      "steel",
      "concrete",
    ]
    unique_materials = toset([
      "concrete",
      "glass",
      "steel",
    ])

## The datasheet (Phase 3)

    == Torre Aurora ==
    floors     : 42
    height     : 191.5 m
    certified  : true
    street     : Via dei Grafi 4
    ground area: 650 sqm
    latitude   : 45.4642
    materials  : concrete, glass, steel

## fmt at work (Phase 4)

    -      lobby_name= "Atrio Nord"
    -  lobby_seats =        18
    +  lobby_name  = "Atrio Nord"
    +  lobby_seats = 18

## The three questions

**a. Blocks versus arguments, and why HCL exists.**

A labelled block: resource "local_file" "datasheet" — a type plus two
quoted labels, then a body in braces, no equals sign anywhere on that
line. A nested block: required_providers inside terraform — again a name
straight into braces, no equals. An argument: content = local.datasheet —
name, equals, expression. The equals sign is the whole tell. As for why
HCL exists: this very file is the answer. It is full of comments (JSON
admits none), and to the right of the equals signs live real expressions —
interpolations, references like local.address.street, a function call —
where JSON could only hold inert strings that some other layer would have
to parse and re-interpret. HCL is data a human writes and reasons about;
JSON is data a machine exchanges.

**b. The types: list vs set, map vs object, and the nameless tuple.**

The second "steel" survived in materials — position 1 and position 3, in
exactly the order written — and vanished in unique_materials, which came
back alphabetical and labelled toset: the set threw away the duplicate and
the order, because membership is the only thing it knows. So: list when
order or repetition carry meaning (laying sequence, retry attempts), set
when only presence matters (which materials appear in the building). The
areas are a map because every value has the same shape — a number per
named key, and more floors would just be more keys. The address is an
object because the fields have different types (string, number, bool) and
a fixed structure: it is one thing with parts, not a collection of alike
things. The tuple needs no names because position IS the meaning:
coordinates[0] is the latitude by convention, exactly like in geography.

**c. Strings and form: the heredoc dash, interpolation, and what fmt never
changes.**

The dash in <<-EOT strips the leading indentation from every line, so the
heredoc can sit nicely indented inside the locals block while the produced
text starts at column zero — without the dash, the datasheet would carry
the indentation into the file. The interpolation ${...} evaluates an
expression and splices its value into the string: the card is a template
whose holes are filled from the model at plan time. fmt aligned the equals
signs in a column, fixed the indentation and normalised the spacing —
and it would never rename lobby_seats, reorder the arguments, or turn 18
into anything else: it edits layout, not meaning. That guarantee is
precisely what makes it safe as an automatic CI step: it can rewrite every
file in the repository and, by construction, no plan will ever change
because of it.
