# json-query

A minimal JSON query tool for the command line, written in Haskell.

Queries navigate into a JSON document using a simple path syntax and print the result.

## Building

Requires [GHC](https://www.haskell.org/ghc/) and [Cabal](https://www.haskell.org/cabal/).

```sh
cabal build
```

## Running

```sh
cabal run json-query -- <query> <json-file>
```

Or, after a build:

```sh
cabal exec json-query -- <query> <json-file>
```

### Query language

| Syntax          | Description                                  |
|-----------------|----------------------------------------------|
| `.field`        | Access a field on a JSON object              |
| `[n]`           | Access an element in a JSON array by index   |
| `["field"]`     | Alternative syntax for field access          |

Steps can be chained:

- `.store.book[0].title`
- `.employees["alice"].salary`

**Tip:** Queries containing brackets (`[`, `]`) must be quoted to prevent shell globbing.

### Examples

```sh
cabal run json-query -- .name examples/sample.json
# "ACME Store"

cabal run json-query -- '.items[0].name' examples/sample.json
# "Widget"

cabal run json-query -- '.items[0].tags[0]' examples/sample.json
# "gadget"

cabal run json-query -- .employees.alice.salary examples/sample.json
# 75000

cabal run json-query -- .location examples/sample.json
# "New York"
```

## Testing

```sh
cabal test
```

## Project structure

```
src/
  Formatter.hs          — JSON value → string formatting
  QueryLang/
    Types.hs            — Step and Query data types
    Parser.hs           — Query string → Query AST
    Evaluator.hs        — Query AST → Value evaluation
app/
  Main.hs               — CLI entry point
test/
  Spec.hs               — Hspec test suite
examples/
  sample.json           — Sample data for manual testing
```
