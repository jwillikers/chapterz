#!/usr/bin/env nu

# todo Add a flag to combine chapters split into multiple parts.

use std log

export const chapterz_version = "0.0.1"
export const user_agent = $"chapterz/($chapterz_version) \( https://github.com/jwillikers/chapterz \)"

# Get a list of start offsets from a list of durations
export def lengths_to_start_offsets []: [
  list<duration> -> list<duration>
] {
  $in
  | reduce --fold {total: 0ms offsets: []} {|length, acc|
    {
      total: ($acc.total + $length)
      offsets: ($acc.offsets | append $acc.total)
    }
  }
  | get offsets
}

# Format the duration of a chapter in format used for audiobook chapters
export def format_chapter_duration []: duration -> string {
  # HH:MM:SS.fff
  let time = $in
  let hours = (
    ($time // 1hr)
    | fill --alignment right --character "0" --width 2
  )
  let minutes = (
    ($time mod 1hr // 1min)
    | fill --alignment right --character "0" --width 2
  )
  let seconds = (
    ($time mod 1min // 1sec)
    | fill --alignment right --character "0" --width 2
  )
  let fractional_seconds = (
    ($time mod 1sec / 1sec * 1000 // 1)
    | fill --alignment right --character "0" --width 3
  )
  $"($hours):($minutes):($seconds).($fractional_seconds)"
}

export def round_to_second_using_cumulative_offset []: list<duration> -> list<duration> {
  let i = $in
  $i | reduce --fold {durations: [], cumulative_offset: 0.0} {|it, acc|
  # $i | reduce {|it, acc|
    let seconds = $it / 1sec
    let floor = $seconds // 1
    let ceil = ($seconds // 1) + 1
    let floor_offset = $floor - $seconds
    let ceil_offset = $ceil - $seconds
    let duration_and_offset = (
      if (($acc.cumulative_offset + $floor_offset) | math abs) <= (($acc.cumulative_offset + $ceil_offset) | math abs) {
        # round down
        {
          cumulative_offset: ($acc.cumulative_offset + $floor_offset)
          duration: ($floor | into int | into duration --unit sec)
        }
      } else {
        # round up
        {
          cumulative_offset: ($acc.cumulative_offset + $ceil_offset)
          duration: ($ceil | into int | into duration --unit sec)
        }
      }
    )

    {
      durations: ($acc.durations | append $duration_and_offset.duration)
      cumulative_offset: $duration_and_offset.cumulative_offset
    }
  } | get durations
}

# Fetch a release from MusicBrainz by ID
export def get_musicbrainz_release []: string -> record {
  let id = $in
  let url = "https://musicbrainz.org/ws/2/release"
  http get --headers [User-Agent $user_agent Accept "application/json"] $"($url)/($id)/?inc=recordings"
}

# Parse chapters out of MusicBrainz recordings data in the chapters.txt format.
# $release | get media
export def chapters_from_musicbrainz_release_media []: table -> string {
  let tracks = $in | get tracks | flatten
  let start_offsets = (
    $tracks
    | get length
    | each {|length| $length | into duration --unit ms }
    | lengths_to_start_offsets
  )
  $tracks
  | enumerate
  | each {|t|
    $"($start_offsets | get $t.index | format_chapter_duration) ($t.item.title)"
  }
  | str join "\n"
}

# Format the duration of a chapter as HH:MM:SS, rounded to the nearest second, as used by MusicBrainz track lengths.
export def format_musicbrainz_length []: duration -> string {
  let seconds = ($in / 1sec | math round | into int)
  let hours = $seconds // 3600 | fill --alignment right --character "0" --width 2
  let minutes = $seconds mod 3600 // 60 | fill --alignment right --character "0" --width 2
  let seconds = $seconds mod 60 | fill --alignment right --character "0" --width 2
  $"($hours):($minutes):($seconds)"
}

# Determine the type of input.
#
# Returns one of "m4b", "chapters.txt", "MusicBrainz", "ASIN", or null when the input is unsupported.
export def detect_input_type []: string -> any {
  let input = $in
  let parsed = $input | path parse
  if $parsed.extension == "m4b" {
    "m4b"
  } else if $parsed.stem == "chapters" and $parsed.extension == "txt" {
    "chapters.txt"
  } else if $input =~ '[a-zA-Z0-9]{8}-[a-zA-Z0-9]{4}-[a-zA-Z0-9]{4}-[a-zA-Z0-9]{4}-[a-zA-Z0-9]{12}' {
    "MusicBrainz" # Release ID
  } else if $input =~ '[a-zA-Z0-9]{10}' {
    "ASIN"
  } else {
    null
  }
}

# Determine if the chapters are named according to standard defaults.
#
# Default naming schemes:
#
# Libro.fm: Title - Track <x>
# Audible: Chapter <x>
#
export def has_default_chapters []: table<index: int, title: string, duration: duration> -> bool {
  let chapters = $in
  if ($chapters | is-empty) {
    return false
  }
  (
    (
      $chapters | all {|c|
        $c.title =~ '^Chapter [0-9]+$'
      }
    ) or (
      $chapters | all {|c|
        $c.title =~ ' - Track [0-9]+$'
      }
    )
  )
}

# Rename chapters.
#
# Note that the indices most be 1-based and not 0-based.
#
export def rename_chapters [
  --chapter-word: string = "Chapter" # The string to use for the name of each chapter. This is usually "Chapter".
  --offset: int # The difference between the track indices and the chapter numbers, i.e. the chapter number is the track index minus this value
  --prefix: string # A prefix to add before the name of each chapter
  --suffix: string # A suffix to add after the name of each chapter
]: table<index: int, title: string, duration: duration> -> table<index: int, title: string, duration: duration> {
  let chapters = $in
  if ($chapters | length) <= 1 {
    return $chapters
  }
  let chapters = $chapters | sort-by index
  # todo Handle indexing automatically when it isn't 1-based.
  if ($chapters | first | get index) != 1 {
    error make {msg: "rename_chapters requires 1-based indices"}
  }
  let offset = (
    if $offset == null {
      let c = $chapters | first;
      if $c.duration < 1min {
        1
      } else {
        0
      }
    } else {
      $offset
    }
  )
  $chapters | each {|c|
    if $c.index == 1 {
      if $c.duration < 1min {
        $c | update title "Opening Credits"
      } else {
        if $c.index - $offset == 0 {
          $c | update title "Opening Credits / Prologue"
        } else {
          $c | update title $"Opening Credits / ($prefix)($chapter_word) ($c.index - $offset)($suffix)"
        }
      }
    } else if $c.index == ($chapters | length) {
      if $c.duration < 3min {
        $c | update title "Closing Credits"
      } else {
        $c | update title $"($prefix)($chapter_word) ($c.index - $offset)($suffix) / Closing Credits"
      }
    } else {
      if $c.index - $offset == 0 {
        if $c.duration < 1min {
          $c | update title "Epigraph"
        } else {
          $c | update title "Prologue"
        }
      } else {
        $c | update title $"($prefix)($chapter_word) ($c.index - $offset)($suffix)"
      }
    }
  }
}

# # Find all unquoted forward slashes in a string
# export def indices_of_unquoted_forward_slashes []: string -> list<int> {
#     let input = $in
#     # todo Handle nested quotes
#     for quote in ["'", '"'] {
#         let first_single_quote $input | str index-of $quote --range 0
#     }
#     []
# }

# Remove a matching pair of quotes surrounding a string.
export def unquote []: string -> string {
  $in | str trim | str replace --regex '^"(.*)"$|^“(.*)”$|^\x27(.*)\x27$' '$1$2$3'
}

# Parse the Part, Chapter, and Title portions of a chapter.
#
# Handles titles following the MusicBrainz Audiobook style guideline, with or without quotes around the titles.
#
# Part One: "The Part Title", Chapter 1: "The Chapter Title", Part 1
# Part One, Chapter 1: The Chapter Title
# Chapter 1: The Chapter Title, Part 1
# Epigraph / Chapter 1: The Chapter Title
#
# Tracks combined with " / " are split into their labels and titles, which are each joined with " / ".
# Quote a part title that contains a comma so that it isn't mistaken for the end of the part.
export def parse_chapter_title []: string -> record<part: any, part_title: string, chapter: string, chapter_title: string, chapter_part: any> {
  let input = $in | str trim

  # A trailing ", Part <n>" indicates that this is one part of a chapter split across multiple tracks.
  let chapter_part_regex = ',\s+(Part \d+)(?=\s+/\s|$)'
  let chapter_part = $input | parse --regex $chapter_part_regex | get capture0?.0?
  let rest = $input | str replace --regex $chapter_part_regex ''

  # A leading "Part <x>", optionally with a title, followed by a comma and the chapter.
  let part = $rest | parse --regex '^(?<part>Part \w+)(?::\s*(?<part_title>"[^"]*"|“[^”]*”|[^,]*))?,\s+(?<rest>.+)$' | get 0?
  let rest = if $part == null { $rest } else { $part.rest }

  # Split combined tracks on " / " outside of double quotes.
  let segments = (
    $rest
    | split row --regex '\s+/\s+(?=(?:[^"]*"[^"]*")*[^"]*$)'
    | each {|segment|
      let parsed = $segment | parse --regex '^(?<label>[^:]+?)(?::\s*(?<title>.*))?$' | first
      {
        label: ($parsed.label | str trim)
        title: ($parsed.title | default "" | unquote)
      }
    }
  )

  {
    part: $part.part?
    part_title: ($part.part_title? | default "" | unquote)
    chapter: ($segments.label | str join " / ")
    chapter_title: ($segments.title | where {|t| $t | is-not-empty } | str join " / ")
    chapter_part: $chapter_part
  }
}

# Combine chapters split into multiple parts into complete chapters
#
# Only works for chapters titled according to the MusicBrainz Audiobook style guidelines.
export def combine_chapter_parts []: table<index: int, title: string, duration: duration> -> table<index: int, title: string, duration: duration> {
  let chapters = $in
  let index_offset = $chapters.index | first
  (
    $chapters
    | each {|chapter|
      $chapter | update title (
        $chapter.title
        | parse --regex '(?P<title>.*?)(?P<part>, Part [0-9]+)?$'
        | first
      )
    }
    | reduce {|it acc|
      if ($acc | is-empty) {
        $acc | append $it
      } else {
        let last = (
          if ($acc | describe | str starts-with record) {
            $acc
          } else {
            $acc | last
          }
        )
        if $last.title.title == $it.title.title {
          let updated = $last | update duration ($last.duration + $it.duration)
          if $acc == $last {
            $updated
          } else {
            $acc | drop | append $updated
          }
        } else {
          $acc | append $it
        }
      }
    }
    | enumerate
    | each {|chapter|
      {
        index: ($chapter.index + $index_offset)
        title: $chapter.item.title.title
        duration: $chapter.item.duration
      }
    }
  )
}

export const chapter_formats = ["musicbrainz" "chapters.txt" "tone" "OpenLibrary" "debug"]

# Format chapters for output.
#
# Start offsets are determined by the order of the chapters, so the indices may begin at any number.
export def format_chapters [
  --format: string = "musicbrainz" # One of "musicbrainz", "chapters.txt", "tone", "OpenLibrary", or "debug"
]: table<index: int, title: string, duration: duration> -> list<any> {
  let chapters = $in
  if $format not-in $chapter_formats {
    error make {msg: $"Unsupported format ($format). Supported formats are ($chapter_formats | str join ', ')."}
  }
  let start_offsets = $chapters | get duration | lengths_to_start_offsets
  $chapters
  | enumerate
  | each {|it|
    let c = $it.item
    let start_offset = $start_offsets | get $it.index
    let length = $c.duration | format_musicbrainz_length
    match $format {
      "musicbrainz" => $"($c.index) ($c.title) \(($length)\)"
      "chapters.txt" => $"($start_offset | format_chapter_duration) ($c.title)"
      "tone" => {
        index: $c.index
        start: (($start_offset / 1ms) | math round)
        length: (($c.duration / 1ms) | math round)
        title: $c.title
      }
      "OpenLibrary" => {
        let chapter_components = $c.title | parse_chapter_title
        # todo Handle parts.
        $"* ($chapter_components.chapter) | ($chapter_components.chapter_title) | ($start_offset | format_chapter_duration)"
      }
      "debug" => {
        index: $c.index
        title: $c.title
        duration: $c.duration
        duration_millis: ($c.duration | format duration ms)
        chapters_txt_start_offset: ($start_offset | format_chapter_duration)
        musicbrainz_length: $length
      }
    }
  }
}

# Print out the chapters for an audiobook in the format used when adding the track list to MusicBrainz.
#
# Takes the path to an M4B file, an Audible ASIN, or a MusicBrainz Release ID.
#
def main [
  input: string
  --format: string = "musicbrainz" # Can also be "chapters.txt", tone, "OpenLibrary", or "debug". The OpenLibrary format is for the table of contents of an edition in OpenLibrary.
  --chapter-offset: any # The difference between the track indices and the chapter numbers, i.e. the chapter number is the track index minus this value
  --chapter-prefix: string # A prefix to add before the title of each chapter
  --chapter-suffix: string # A suffix to add after the title of each chapter
  --chapter-word: string = "Chapter" # The string to use for the name of each chapter. This is usually "Chapter".
  --rename-chapters: any = null # Whether to automatically rename the chapters using sensible defaults. Renames by default when the detected chapters appear to be named according to standard defaults.
  --round # Force rounding when outputting in the chapters.txt format
] {
  if $format not-in $chapter_formats {
    log error $"Unsupported format (ansi purple)($format)(ansi reset). Supported formats are ($chapter_formats | str join ', ')."
    exit 1
  }
  let input_type = $input | detect_input_type
  if $input_type == "chapters.txt" {
    log error $"Unsupported input (ansi purple)($input)(ansi reset). Use embed-chapterz.nu to embed a chapters.txt file."
    exit 1
  }
  if $input_type == null {
    log error $"Unsupported input (ansi purple)($input)(ansi reset)"
    exit 1
  }

  let chapters = (
    if $input_type == "m4b" {
      ^tone dump --format json $input
      | from json
      | get meta
      | get chapters
      | enumerate
      | each {|c|
        {
          index: ($c.index + 1)
          title: $c.item.title
          duration: ($c.item.length | into duration --unit ms)
        }
      }
    } else if $input_type == "ASIN" {
        http get --headers [User-Agent $user_agent Accept "application/json"] $"https://api.audnex.us/books/($input)/chapters"
        | get chapters
        | enumerate
        | each {|c|
          {
            index: ($c.index + 1)
            title: $c.item.title
            duration: ($c.item.lengthMs | into duration --unit ms)
          }
        }
    } else if $input_type == "MusicBrainz" {
      (
        $input
        | get_musicbrainz_release
        | get media
        | get tracks
        | flatten
        | enumerate
        | each {|recording|
          {
            index: ($recording.index + 1)
            title: $recording.item.title
            duration: ($recording.item.length | into duration --unit ms)
          }
        }
      )
    }
  )
  let chapters = (
    if $format == "musicbrainz" or $round {
      let durations = $chapters | get duration | round_to_second_using_cumulative_offset
      $chapters | merge ($durations | wrap duration)
    } else {
      $chapters
    }
  )
  let rename_chapters = (
    if $rename_chapters == null {
      $chapters | has_default_chapters
    } else {
      $rename_chapters
    }
  )

  # Rename chapters
  let chapters = (
    if $rename_chapters {
      if $chapter_offset == null {
        $chapters | rename_chapters --chapter-word $chapter_word --prefix $chapter_prefix --suffix $chapter_suffix
      } else {
        $chapters | rename_chapters --chapter-word $chapter_word --offset $chapter_offset --prefix $chapter_prefix --suffix $chapter_suffix
      }
    } else {
      $chapters
    }
  )

  (
    $chapters
    | format_chapters --format $format
    | (
      let i = $in;
      if $format == "tone" {
        $i
      } else if $format == "debug" {
        $i | print
      } else {
        $i | print --raw
      }
    )
  )
}
