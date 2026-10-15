# Strings

Thai is the source language; English is the second. Every user-visible string
lives in an ARB fragment here, one pair per area: `<area>.th.arb` and
`<area>.en.arb`. They merge into `lib/l10n/app_*.arb`:

    python3 tool/l10n_merge.py && flutter gen-l10n

Read strings with `context.l10n.someKey` (import `l10n/l10n.dart`). Keys are
camelCase, prefixed by the area (`home…`, `picker…`), unique across areas, and
present in both languages. Placeholders need an `@key` block with types.
Thai text must stay exactly as it was in the code.
