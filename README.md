# n150 componentized ops

## Interface

- `make <component>-<verb>`
- `scripts/bin/n150 <component> <verb> [args]`

## Components

- `net`, `app`, `monitoring`, `proxy`, `backup`

## Verbs

- `install`, `secrets`, `secrets-deploy`, `start`, `stop`, `restart`, `status`, `check`, `run`

## Output policy

- Only `help` prints descriptive usage text.
- All other commands are quiet-by-default; errors go to stderr and return non-zero.
