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

export extern "main" [ # A command line tool for creating Minecraft modpacks
  --cache: path             # The directory where packwiz will cache downloaded mods (default "/home/kodie/.cache/packwiz/cache")
  --config: path            # The config file to use (default "/home/kodie/.config/packwiz/.packwiz.toml")
  --meta-folder: path       # The folder in which new metadata files will be added, defaulting to a folder based on the category (mods, resourcepacks, etc; if the category is unknown the current directory is used)
  --meta-folder-base: path  # The base folder from which meta-folder will be resolved, defaulting to the current directory (so you can put all mods/etc in a subfolder while s till using the default behaviour) (default ".")
  --pack-file: path         # The modpack metadata file to use (default "pack.toml")
  --yes(-y)                 # Accept all prompts with the default or "yes" option (non-interactive mode) - may pick unwanted options in search results
] {}

export extern "cf" [] {} # Manage curseforge-based mods

export extern "gh" [] {} # Manage projects released on GitHub

export extern "mr" [] {} # Manage modrinth-based mods
export extern "mr add" [ # Add a project from a Modrinth URL, slug/project ID or search
  ...slug: string,
  --project-id: string,       # The Modrinth project ID to use
  --version-filename: string, # The Modrinth version filename to use
  --version-id: string        # The Modrinth version ID to use
] {}
export extern "mr export" [] {} # Manage modrinth-based mods

export extern "url" [] {} # Add external files from a direct download link, for sites that are not directly supported by packwiz
export extern "url add" [ # Add external files from a direct download link, for sites that are not directly supported by packwiz
  name: string
  url: string
  --meta-name: string # Filename to use for the created metadata file (defaults to a name generated from the name you supply)
  --force # Add a file even if the download URL is supported by packwiz in an alternative command (which may support dependencies and updates)
] {}

export extern "rm" [file: string@metafiles] {} # Remove an external file from the modpack; equivalent to manually removing the file and running packwiz refresh

export extern "pin" [file: string@metafiles] {} # Pin a file so it does not get updated automatically
export extern "unpin" [file: string@metafiles] {} # Unpin a file so it receives updates

export extern "init" [] {} # Initialise a packwiz modpack
export extern "list" [] {} # List all the mods in the modpack
export extern "migrate" [] {} # Migrate your Minecraft and loader versions to newer versions.
export extern "refresh" [] {} # Refresh the index file
export extern "rehash" [] {} # Migrate all hashes to a specific format
export extern "serve" [] {} # Run a local development server
export extern "settings" [] {} # Manage pack settings
export extern "update" [
  file?: string@metafiles
  --all
] {} # Update an external file (or all external files) in the modpack
export extern "utils" [] {} # Utilities for managing packwiz itself
