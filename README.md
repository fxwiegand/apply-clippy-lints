# apply-clippy-lints
A GitHub action that applies lints from clippy and creates a new PR automatically to keep your code clean and up-to-date.

### Usage

```
autofix:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repository
        uses: actions/checkout@v2
      - name: Auto apply clippy lints
        uses: fxwiegand/apply-clippy-lints@v1
        with:
          toolchain: stable
```

### Options

| Option    | explanation                                                                                                      | default |
|-----------|------------------------------------------------------------------------------------------------------------------|---------|
| toolchain | The rust toolchain to use                                                                                        | stable  |
