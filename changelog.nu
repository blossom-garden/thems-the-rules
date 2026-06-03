#!/usr/bin/env nu

def main [] {
  let diff = git log -5 --name-status --pretty=format:"%H" --diff-filter=AD
  | lines
  | chunk-by {|it| $it | is-not-empty}
  | where ($it.0 | is-not-empty)
  | each {|chunk|
    let hash = $chunk.0
    $chunk | skip 1 | each {|file|
      let parsed = ($file | parse -r '^(\S+)\s+(.+)$')
      {status: $parsed.0.capture0, file: $parsed.0.capture1, hash: $hash}
    }
  }
  | flatten | where $it.file =~ '.pw.toml'

  # let getteradded = {|it| (git show ($it.hash):($it.file) | from toml)}

  let added = $diff | where status == 'A' | getteradded | str join "\n"
  let removed = $diff | where status == 'D' | getterremoved | str join "\n"

  mut markdown = $"\n**((open pack.toml).version)**"
  if ($added | is-not-empty) { $markdown = ([$markdown $"**Adicionado**\n\n($added)"] | str join "\n\n") }
  if ($removed | is-not-empty) { $markdown = ([$markdown $"**Removido**\n\n($removed)"] | str join "\n\n") }
  $markdown
}

def getterremoved [] {
  $in
  | each {|it|
    git show $"($it.hash)~1:($it.file)" | from toml
  }
  | where update? != null
  | gettermetadata
  | link
}

def getteradded [] {
  $in
  | each {|it|
    git show ($it.hash):($it.file) | from toml
  }
  | where update? != null
  | gettermetadata
  | link
}

def gettermetadata [] {
  $in
  | each {|it|
    let provider = $it | get update? | columns | first
    let id = match $provider {
      "modrinth" => ($it | get update.modrinth.mod-id?),
      "curseforge" => ($it | get update.curseforge.project-id?),
      _ => "",
    }
    { name: $in.name, provider: $provider, id: $id }
  }
}

def link [] {
  $in
  | each {|it|
    let url: string = match $it.provider {
      "modrinth" => $"https://modrinth.com/project/($it.id)",
      "curseforge" => $"https://curseforge.com/projects/($it.id)",
      _ => "",
    }
    let name: string = $it.name | str trim | str escape-regex
    $"- [($name)]\(($url)\)"
  }
}
