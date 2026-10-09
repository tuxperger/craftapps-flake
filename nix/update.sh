# Refresh nix/sources.json from the latest GitHub release of every app.
# Run through the flake: `nix run .#update` (from the repo root). APPS is set by the wrapper.
#
# Hashes come from the release asset digests reported by the GitHub API, so nothing is downloaded.
# Set GITHUB_TOKEN to avoid the anonymous API rate limit.

out=nix/sources.json
[ -d nix ] || { echo "run from the repository root" >&2; exit 1; }

auth=()
[ -n "${GITHUB_TOKEN:-}" ] && auth=(-H "Authorization: Bearer $GITHUB_TOKEN")

result='{}'
for app in $APPS; do
  release=$(curl -fsSL "${auth[@]}" "https://api.github.com/repos/storytold/$app/releases/latest")
  entry=$(jq '
    (.tag_name | ltrimstr("v")) as $version
    | [.assets[] | select(.name | endswith(".deb"))] as $debs
    | {
        version: $version,
        # The package name inside the release can differ from the repo name (printcraft ships pdfcraft).
        debName: ($debs[0].name | split("-" + $version + "-linux-")[0]),
        sha256: ($debs | map({
          key: (.name | capture("-linux-(?<arch>[^.]+)\\.deb$").arch + "-linux"),
          value: (.digest | ltrimstr("sha256:"))
        }) | from_entries)
      }' <<<"$release")
  echo "$app $(jq -r '.version' <<<"$entry")"
  result=$(jq --arg app "$app" --argjson entry "$entry" '.[$app] = $entry' <<<"$result")
done

jq -S . <<<"$result" > "$out"
