export def "all" []: nothing -> string { # Command to generate a list of all mods in the modpack in Markdown format
  ls **/*.pw.toml
  | get name
  | each {open}
  | get metadata
  | get link
  | str join "\n"
}

export def "all details" []: nothing -> string { # Command to generate a list of all mods in the modpack in Markdown format but with a <details> element
  $"<details>\n\n<summary>Modlist</summary>\n\n(all)\n\n</details>"
}

export def "changelog" [commits: int = 5]: nothing -> string { # Command to generate a changelog in Markdown format
  let diff = git log $"-($commits)" --name-status --pretty=format:"%H" --diff-filter=ADM
  | lines
  | chunk-by {is-not-empty}
  | where ($it.0 | is-not-empty)
  | each {|chunk|
    $chunk | skip 1 | each {|file|
      let parsed = ($file | parse -r '^(\S+)\s+(.+)$')
      {status: $parsed.0.capture0, file: $parsed.0.capture1, hash: $chunk.0}
    }
  }
  | flatten
  | where $it.file =~ '.pw.toml'

  let added = $diff | where status == 'A' | file added | get link | str join "\n"
  let removed = $diff | where status == 'D' | file removed | get link | str join "\n"
  let modified = $diff | where status == 'M' | file added | get link | str join "\n"

  [
    $"**((open pack.toml).version)**"
    (if ($added | is-not-empty) {$"**Adicionado**\n\n($added)"} else {null})
    (if ($modified | is-not-empty) {$"**Modificado/Atualizado**\n\n($modified)"} else {null})
    (if ($removed | is-not-empty) {$"**Removido**\n\n($removed)"} else {null})
  ] | each {$in} | str join "\n\n"
}

export def "file changelog" [commits: int, file: path]: nothing -> string {
  let insert_pattern = "<!-- INSERT-NEW-CHANGELOG -->"
  let changelog_old: string = open -r $file
  $changelog_old
  | str replace -a $insert_pattern $"($insert_pattern)\n\n(changelog $commits)"
}

export def "file details" [file: path]: nothing -> string {
  let insert_pattern = "(?s)<details>.*</details>"
  let details_old: string = open -r $file
  $details_old
  | str replace -r $insert_pattern (all details)
}

def "get metadata" []: [
  table -> table<name: string, provider: string, id: string>
  table -> table<name: string, provider: string, id: int>
] {
  each {|it|
    let provider: string = ($it | get update? | default {} | columns | first | default "none")
    match $provider {
      "modrinth" => { name: $it.name, provider: $provider, id: ($it | get update.modrinth.mod-id?) },
      "curseforge" => { name: $it.name, provider: $provider, id: ($it | get update.curseforge.project-id?) },
      _ => null,
    }
  }
}

def "get link" []: table -> list<string> {
  each {|it|
    let name = $it.name | str trim | str escape-regex
    match $it.provider {
      "modrinth" => $"- [($name)]\(https://modrinth.com/project/($it.id)\)",
      "curseforge" => $"- [($name)]\(https://curseforge.com/projects/($it.id)\)",
      _ => null
    }
  }
}

def "file added" []: table -> table<name: string, id: any, provider: any> {
  $in
  | each {|it| (git show ($it.hash):($it.file) | from toml)}
  | where update? != null
  | get metadata
}

def "file removed" []: table -> table<name: string, id: any, provider: any> {
  $in
  | each {|it| (git show $"($it.hash)~1:($it.file)" | from toml)}
  | where update? != null
  | get metadata
}
