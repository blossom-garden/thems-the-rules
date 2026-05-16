#!/usr/bin/env nu

# Import modrinth and curseforge mods from a list of project urls
export def "import" [
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
export def "export" []: nothing -> string {
  let list: table<name: string, id: any, provider: string> = ls **/*.pw.toml
  | each {|it| open $it.name}
  | where update? != null
  | each {|it| $it | get-metadata}

  let markdown: string = [$"\n**((open pack.toml).version)**" ($list | each {|it|
    let url: string = match $it.provider {
      "modrinth" => $"https://modrinth.com/project/($it.id)",
      "curseforge" => $"https://curseforge.com/projects/($it.id)",
      _ => "#nope",
    }
    $"- [($it.name)]\(($url)\)"
  } | str join "\n")] | str join "\n\n"

  $markdown
}

def get-metadata []: [
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

def generate-link []: record<name: string, id: any, provider: string> -> string {
    let url: string = match $in.provider {
      "modrinth" => $"https://modrinth.com/project/($in.id)",
      "curseforge" => $"https://curseforge.com/projects/($in.id)",
      _ => ""
    }
    let name: string = ($in.name | str trim | str replace -ra '(?<bracket>[\[\]])' '\$bracket')
    $"- [($name)]\(($url)\)"
}

def "get added" [diff: table<status: string, file: string>]: nothing -> table<name: string, id: any, provider: string> {
  $diff
  | where status == "A" | get file | each {|it| open $it}
  | where update? != null
  | each {|it| $it | get-metadata }
}

def "get removed" [diff: table<status: string, file: string>]: nothing -> table<name: string, id: any, provider: string> {
  $diff
  | where status == "D" | get file | each {|it| (git show HEAD~1:($it) | from toml) }
  | where update? != null
  | each {|it| $it | get-metadata }
}

# Returns the most recently added files
export def "changelog" []: nothing -> string {
  let diff: table<status: string, file: string> = git diff --name-status HEAD~1...
  | str replace -r -a "\t" "»¦«"
  | lines | where $it =~ ".pw.toml"
  | split column "»¦«" status file
  | append (git diff --name-status --cached
    | str replace -r -a "\t" "»¦«"
    | lines | where $it =~ ".pw.toml"
    | split column "»¦«" status file)

  let added = get added $diff
  let removed = get removed $diff

  let added_links = $added | each {|i| $i | generate-link } | str join "\n"
  let removed_links = $removed | each {|i| $i | generate-link } | str join "\n"

  mut markdown = $"\n**((open pack.toml).version)**"
  if ($added_links | is-not-empty) { $markdown = ([$markdown $"**Adicionado**\n\n($added_links)"] | str join "\n\n") }
  if ($removed_links | is-not-empty) { $markdown = ([$markdown $"**Removido**\n\n($removed_links)"] | str join "\n\n") }
  $markdown
}

def semver-level [] {[ "major" "minor" "patch" "alpha" "beta" "rc" "release"]}

# Semver Bump the pack
export def bump [level: string@semver-level] {
  mut pack: table = (open pack.toml)
  $pack.version = $"($pack.version | semver bump patch)"
  ($pack | save -fp pack.toml)
}
