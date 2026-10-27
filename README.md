# apply-clippy-lints
A GitHub action that applies lints from clippy and creates a new PR automatically to keep your code clean and up-to-date.

### Usage

```yaml
autofix:
    runs-on: ubuntu-latest
    permissions:
      contents: write
      pull-requests: write
    steps:
      - name: Checkout repository
        uses: actions/checkout@v7
      - name: Auto apply clippy lints
        uses: fxwiegand/apply-clippy-lints@v1.1.0 # x-release-please-version
        with:
          toolchain: stable
```

The PR is created with the default `GITHUB_TOKEN`, so "Allow GitHub Actions to create and approve pull requests" has to be enabled in the repository settings under Actions > General.

### PR summary

The PR body lists the applied fixes per lint, with links to the clippy docs, and the warnings that are left for manual fixing. The same summary is shown in the job summary of the workflow run.

### Options

| Option         | explanation                                      | default                             |
|----------------|--------------------------------------------------|-------------------------------------|
| toolchain      | The rust toolchain to use                        | stable                              |
| commit-message | The commit message and title of the generated PR | refactor: Apply latest clippy lints |

### Outputs

| Output                 | explanation                                                          |
|------------------------|----------------------------------------------------------------------|
| pull-request-number    | The number of the created or updated PR                              |
| pull-request-url       | The URL of the created or updated PR                                 |
| pull-request-operation | The operation performed on the PR (created, updated, closed or none) |
