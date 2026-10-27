#!/usr/bin/env bash
# Builds a markdown summary of the fixes applied by `cargo clippy --fix`.
#
# Usage: summarize.sh <before.json> <after.json> <fix.log> <clippy version>
#
# before.json and after.json are the outputs of `cargo clippy --message-format=json`
# before and after applying the fixes, fix.log is the stderr of `cargo clippy --fix`.
set -euo pipefail

before=$1
after=$2
fix_log=$3
clippy_version=$4

max_rows=50

# Turns cargo JSON messages into one object per warning, deduplicated by location
# since the same warning is reported once per target (e.g. lib and test).
warnings='
  [ .[]
    | select(.reason == "compiler-message")
    | .message
    | select(.level == "warning" and .code != null)
    | ([.spans[] | select(.is_primary)][0]) as $span
    | select($span != null)
    | {
        lint: .code.code,
        file: $span.file_name,
        line: $span.line_start,
        message: .message,
        url: ([.children[].message
               | select(startswith("for further information visit "))
               | ltrimstr("for further information visit ")][0] // null)
      }
  ]
  | unique_by([.lint, .file, .line, .message])
'

# Markdown helpers.
helpers='
  def cell: tostring | gsub("\\|"; "\\|") | gsub("\n"; " ");
  def lint_link: if .url then "[`\(.lint)`](\(.url))" else "`\(.lint)`" end;
  def file_list: (.[0:5] | map("`\(. | cell)`") | join(", "))
                 + (if length > 5 then " and \(length - 5) more" else "" end);
'

# Fixes per lint: how many warnings of each lint disappeared per file.
fixed=$(jq -s "$warnings" "$before" | jq --argjson after "$(jq -s "$warnings" "$after")" '
  [ (. + $after | map({lint, file}) | unique)[] as $key
    | {
        lint: $key.lint,
        file: $key.file,
        url: ([.[] | select(.lint == $key.lint) | .url][0]),
        count: (([.[] | select(.lint == $key.lint and .file == $key.file)] | length)
                - ([$after[] | select(.lint == $key.lint and .file == $key.file)] | length))
      }
    | select(.count > 0)
  ]
  | group_by(.lint)
  | map({lint: .[0].lint, url: .[0].url, count: (map(.count) | add), files: (map(.file) | unique)})
  | sort_by(-.count, .lint)
')

remaining=$(jq -s "$warnings | sort_by(.file, .line)" "$after")

# Strip colors in case CARGO_TERM_COLOR=always is set.
log=$(sed $'s/\033\\[[0-9;]*m//g' "$fix_log")

# Total reported by cargo itself, e.g. "Fixed src/main.rs (5 fixes)".
cargo_total=$(sed -nE 's/^[[:space:]]*Fixed .* \(([0-9]+) fix(es)?\)$/\1/p' <<< "$log" | awk '{ s += $1 } END { print s + 0 }')
cargo_files=$(grep -cE '^[[:space:]]*Fixed .* \([0-9]+ fix(es)?\)$' <<< "$log" || true)
failed_crates=$(sed -nE 's/^warning: failed to automatically apply fixes suggested by rustc to crate `([^`]+)`.*/\1/p' <<< "$log" | sort -u)

attributed=$(jq '[.[].count] | add // 0' <<< "$fixed")

echo "I found some new fixes for your repository. This PR applies them to your project."
echo

if [ "$cargo_total" -gt 0 ]; then
  fix_word=$([ "$cargo_total" -eq 1 ] && echo fix || echo fixes)
  file_word=$([ "$cargo_files" -eq 1 ] && echo file || echo files)
  echo "### Applied fixes"
  echo
  echo "\`cargo clippy --fix\` applied $cargo_total $fix_word in $cargo_files $file_word."
  echo
  if [ "$attributed" -gt 0 ]; then
    echo "| Lint | Fixes | Files |"
    echo "|------|------:|-------|"
    jq -r "$helpers"' .[] | "| \(lint_link) | \(.count) | \(.files | file_list) |"' <<< "$fixed"
    echo
  fi
  if [ "$cargo_total" -gt "$attributed" ]; then
    echo "$((cargo_total - attributed)) of the fixes could not be attributed to a single lint, for example because they were follow-up fixes of other fixes."
    echo
  fi
else
  echo "Clippy did not find anything to fix, so this PR only contains formatting changes from \`cargo fmt\`."
  echo
fi

if [ -n "$failed_crates" ]; then
  echo "> [!WARNING]"
  echo "> Some fixes were rolled back because the code did not compile after applying them, in crate(s): $(sed 's/.*/`&`/' <<< "$failed_crates" | paste -sd, - | sed 's/,/, /g')."
  echo
fi

remaining_count=$(jq length <<< "$remaining")
if [ "$remaining_count" -gt 0 ]; then
  warning_word=$([ "$remaining_count" -eq 1 ] && echo "warning needs" || echo "warnings need")
  echo "<details>"
  echo "<summary>$remaining_count remaining $warning_word manual attention</summary>"
  echo
  echo "| Lint | Location | Message |"
  echo "|------|----------|---------|"
  jq -r --argjson max "$max_rows" "$helpers"' .[0:$max][] | "| \(lint_link) | `\("\(.file):\(.line)" | cell)` | \(.message | cell) |"' <<< "$remaining"
  if [ "$remaining_count" -gt "$max_rows" ]; then
    echo
    echo "... and $((remaining_count - max_rows)) more."
  fi
  echo
  echo "</details>"
  echo
fi

echo "<sub>Generated with $clippy_version.</sub>"
