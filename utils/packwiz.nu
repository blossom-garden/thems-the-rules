def "metafiles" [context] {
  let values = ls **/*.pw.toml | get name | each {
    let info = open $in
    {
      value: ($in | str replace -ram '((resourcepacks|datapacks|mods)/)?(?<name>\S+)\.pw\.toml' '$name'),
      description: $info.name?,
      pin: ($info.pin? | default false)
    }
  }
  {
    options: {
      case_sensitive: true,
      completion_algorithm: fuzzy,
      sort: true,
    },
    completions: (match ($context | split words | last) {
      pin => ($values | where pin == false),
      unpin => ($values | where pin == true),
      _ => $values,
    })
  }
}

export extern "main" [] {} # A command line tool for creating Minecraft modpacks

export alias "cf" = curseforge
export extern "curseforge" [] {} # Manage curseforge-based mods

export alias "gh" = github
export extern "github" [] {} # Manage projects released on GitHub

export alias "mr" = modrinth
export extern "modrinth" [] {} # Manage modrinth-based mods
export extern "modrinth add" [ # Add a project from a Modrinth URL, slug/project ID or search
  slug: string,
  --project-id: string,       # The Modrinth project ID to use
  --version-filename: string, # The Modrinth version filename to use
  --version-id: string        # The Modrinth version ID to use
] {}
export extern "modrinth export" [] {} # Manage modrinth-based mods

export extern "url" [] {} # Add external files from a direct download link, for sites that are not directly supported by packwiz

export alias "rm" = remove
export extern "remove" [file: string@metafiles] {} # Remove an external file from the modpack; equivalent to manually removing the file and running packwiz refresh

export extern "pin" [file: string@metafiles] {} # Pin a file so it does not get updated automatically
export extern "unpin" [file: string@metafiles] {} # Unpin a file so it receives updates

export extern "init" [] {} # Initialise a packwiz modpack
export extern "list" [] {} # List all the mods in the modpack
export extern "migrate" [] {} # Migrate your Minecraft and loader versions to newer versions.
export extern "refresh" [] {} # Refresh the index file
export extern "rehash" [] {} # Migrate all hashes to a specific format
export extern "serve" [] {} # Run a local development server
export extern "settings" [] {} # Manage pack settings
export extern "update" [] {} # Update an external file (or all external files) in the modpack
export extern "utils" [] {} # Utilities for managing packwiz itself
