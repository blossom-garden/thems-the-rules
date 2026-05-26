#!/usr/bin/env nu

# Import modrinth and curseforge mods from a list of project urls
export def import [
  modlist: path, # The modlist file to read
  --dry-run(-d)  # Do a dry run where packwiz cli wont actually be called (useful for debuging)
]: nothing -> nothing {
  if not ($modlist | path exists) {
    print $'file "($modlist)" not found'
    exit 1
  }

  if not ("./pack.toml" | path exists) and not $dry_run {
    print "No pack.toml found"
    exit 1
  }

  let list: table<provider: string, id: string> = ["provider,id,version" (open $modlist
    | str replace -arm '^#.*' ''
    | str replace -ar 'http(?:s)?:\/\/(?:www\.)?modrinth.com\/[^/]+\/(?<id>[^/\s]+)(?:\/version\/(?<version>[^/\s]+))?' 'modrinth,$id,$version'
    | str replace -ar 'http(?:s)?:\/\/(?:www\.)?curseforge.com\/[^/]+\/(?<id>\S+)' 'curseforge,$id'
    | str replace -ar 'http(?:s)?:\/\/\S*' '')] | str join "\n"
    | from csv

  for record in $list {
    let output = match $record.provider {
      "modrinth" => (add mr $record.id $record.version --dry=$dry_run)
      "curseforge" => (add cf $record.id --dry=$dry_run)
      _ => (null)
    }
    print ($record | insert output $output)
  }

  print $"\n(ansi '#26233a')(ansi {fg: '#c4a7e7', bg: '#26233a'}) ($modlist) imported! (ansi rst)(ansi '#26233a')(ansi rst)"
}

export def "add mr" [id: string, version?: string, --dry]: nothing -> string {
  if $dry { $"add modrinth project ($id)" } else { ^packwiz mr add -y --project-id=($id) --version-id=($version) }
}

export def "add cf" [id: int, --dry]: nothing -> string {
  if $dry { $"add curseforge project ($id)" } else { ^packwiz cf add -y --addon-id $id }
}

# Export all the mods into a modlist in markdown format
export def all []: nothing -> string {
  let list: table<name: string, id: any, provider: string> = ls **/*.pw.toml
  | each {|it| open $it.name}
  | where update? != null
  | each {|it| $it | get metadata}

  [
    $"\n**((open pack.toml).version)**"
    ($list | each {|it| $it | get link } | str join "\n")
  ] | str join "\n\n"
}

export def details []: nothing -> string {
  let ep = all | str trim
  ["<details>\n<summary>Modlist</summary>" $ep "</details>"] | str join "\n\n"
}

# Returns the most recently added files
export def changelog []: nothing -> string {
  if not ("./pack.toml" | path exists) {
    print "No pack.toml found"
    exit 1
  }

  let diff: table<status: string, file: string, hash: string> = git log -5 --name-status --pretty=format:"%H" --diff-filter=AD
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

  let added = $diff | where status == 'A' | get file | each {|i| $i | get link } | str join "\n"
  let removed = $diff | where status == 'D' | get file -r | each {|i| $i | get link } | str join "\n"

  mut markdown = $"\n**((open pack.toml).version)**"
  if ($added | is-not-empty) { $markdown = ([$markdown $"**Adicionado**\n\n($added)"] | str join "\n\n") }
  if ($removed | is-not-empty) { $markdown = ([$markdown $"**Removido**\n\n($removed)"] | str join "\n\n") }
  $markdown
}

def "get metadata" []: [
  record -> record<name: string, provider: string, id: string>
  record -> record<name: string, provider: string, id: int>
] {
    let provider: string = ($in | get update | columns | first)
    let id = match $provider {
      "modrinth" => ($in | get update.modrinth.mod-id?),
      "curseforge" => ($in | get update.curseforge.project-id?),
      _ => "",
    }
    { name: $in.name, provider: $provider, id: $id }
}

def "get link" []: record<name: string, id: any, provider: string> -> string {
    let url: string = match $in.provider {
      "modrinth" => $"https://modrinth.com/project/($in.id)",
      "curseforge" => $"https://curseforge.com/projects/($in.id)",
      _ => ""
    }
    let name: string = $in.name | str trim | str escape-regex
    $"- [($name)]\(($url)\)"
}

def "get file" [--removed(-r)]: table<status: string, file: string, hash: string> -> table<name: string, id: any, provider: string> {
  $in
  | each {|it| (git show (if $removed {$"($it.hash)~1"} else {$it.hash}):($it.file) | from toml)}
  | where update? != null
  | each {|it| $it | get metadata}
}

