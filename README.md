# Spell Game

Three components, three repos:

| Component        | Repo                                            | Path                |
|-------------------|--------------------------------------------------|----------------------|
| Backend (API)      | [SpellBackend](https://github.com/816eric/SpellBackend) | `SpellBackend/`       |
| FlutterSpell        | [FlutterSpell](https://github.com/816eric/FlutterSpell)  | `FlutterSpell/`       |
| FlutterSpell_Game   | tracked directly in this repo                      | `FlutterSpell_Game/`  |

`SpellBackend` and `FlutterSpell` are git submodules — a fresh `git clone` or `git pull` of this repo leaves those two folders empty until you initialize them.

## Cloning

```bash
git clone --recurse-submodules <this-repo-url>
```

## Already cloned without `--recurse-submodules`?

```bash
git submodule update --init --recursive
```

## Pulling later updates

`git pull` on this repo only updates which submodule commit is recorded, not the submodule's own files. After pulling, run:

```bash
git submodule update --init --recursive
```

See [deploy.md](deploy.md) for deployment and local dev instructions.
