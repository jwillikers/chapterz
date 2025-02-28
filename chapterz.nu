#!/usr/bin/env nu

# todo Add a flag to combine chapters split into multiple parts.

use std log

# Get a list of start offsets from a list of durations
export def lengths_to_start_offsets []: list<duration> -> list<duration> {
  let lengths = $in | enumerate
  $lengths | each {|i|
      $lengths | where index < $i.index | reduce --fold 0ms {|it,acc|
          $it.item + $acc
      }
  }
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
  http get --headers [Accept "application/json"] $"($url)/($id)/?inc=artist-credits+labels+recordings"
}

# Parse chapters out of MusicBrainz recordings data.
# $release | get media
export def chapters_from_musicbrainz_release_media []: table -> string {
  (
    $in
    | get tracks
    | flatten
    | each {|recording|
      # Unfortunately, lengths are in seconds and not milliseconds.
      let time = ($recording.length | into duration --unit ms | lengths_to_start_offsets | each {|t| $t | format_chapter_duration})
      $"($time) ($recording.title)"
    }
    | str join "\n"
  )
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
                $c | update title "End Credits"
            } else {
                $c | update title $"($prefix)($chapter_word) ($c.index - $offset)($suffix) / End Credits"
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

# Parse the Part, Chapter, and Title portions of a chapter.
export def parse_chapter_title []: string -> record<part: string, part_title: string, chapter: string, chapter_title: string, chapter_part: string> {
    let input = $in
    let split = str index-of "/"
    (
        $input
        # todo Split into multiple rows if there's a '/'.
        | parse --regex '(?<part>Part \w+)?(?<part_title>: \"[\w\s]+\")?(?:,\s)?(?<chapter>[\w\s/]+(?:\s\d+)?)(?<chapter_title>: \"[\w\s]+\")?(?:,\s)?(?<chapter_part>Part \d+)?'
        | each {|c|
            {
                part: $c.part
                part_title: (
                    $c.part_title
                    | str trim --char ':' --left
                    | str trim --left
                    | str trim --char '"'
                    | str trim --char "'"
                )
                chapter: $c.chapter
                chapter_title: (
                    $c.chapter_title
                    | str trim --char ':' --left
                    | str trim --left
                    | str trim --char '"'
                    | str trim --char "'"
                )
                chapter_part: $c.chapter_part
            }
        }
        | first
    )
}

# Print out the chapters for an audiobook in the format used when adding the track list to MusicBrainz.
#
# Takes the path to an M4B file, an Audible ASIN, or a MusicBrainz Release ID.
#
def main [
    input: string
    --format: string = "musicbrainz" # Can also be "chapters.txt", "OpenLibrary", or "debug". The OpenLibrary format is for the table of contents of an edition in OpenLibrary.
    --chapter-offset: any # The difference between the track indices and the chapter numbers, i.e. the chapter number is the track index minus this value
    --chapter-prefix: string # A prefix to add before the title of each chapter
    --chapter-suffix: string # A suffix to add after the title of each chapter
    --chapter-word: string = "Chapter" # The string to use for the name of each chapter. This is usually "Chapter".
    --rename-chapters: any = null # Whether to automatically rename the chapters using sensible defaults. Renames by default when the detected chapters appear to be named according to standard defaults.
    --round # Force rounding when outputting in the chapters.txt format
] {
    let input_type = (
        if ($input | path parse | get extension) == "m4b" {
          "m4b"
        } else if $input =~ '[a-zA-Z0-9]{8}-[a-zA-Z0-9]{4}-[a-zA-Z0-9]{4}-[a-zA-Z0-9]{4}-[a-zA-Z0-9]{12}' {
          "MusicBrainz" # Release ID
        } else if $input =~ '[a-zA-Z0-9]{10}' {
          "ASIN"
        } else {
          null
        }
    )
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
            http get $"https://api.audnex.us/books/($input)/chapters"
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
                    index: $recording.index
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
    let start_offsets = (
        $chapters | get duration | lengths_to_start_offsets
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
        | each {|c|
            let d = $c.duration
            let seconds = (
                ($d mod 1min) / 1sec
                | math round
            )
            let minutes = (
                ($d mod 1hr) // 1min
                | (
                    let i = $in;
                    if $seconds == 60 { $i + 1 } else { $i }
                )
            )
            let hours = (
                $d // 1hr
                | (
                    let i = $in;
                    if $minutes == 60 { $i + 1 } else { $i }
                )
                | into string
                | fill --width 2 --alignment right --character '0'
            )
            let seconds = (
                (if $seconds == 60 { 0 } else $seconds)
                | into string
                | fill --width 2 --alignment right --character '0'
            )
            let minutes = (
                (if $minutes == 60 { 0 } else $minutes)
                | into string
                | fill --width 2 --alignment right --character '0'
            )
            if $format == "musicbrainz" {
                $"($c.index) ($c.title) \(($hours):($minutes):($seconds)\)"
            } else if $format == "chapters.txt" {
                let offset = $start_offsets | get ($c.index - 1) | format_chapter_duration
                $"($offset) ($c.title)"
            } else if $format == "OpenLibrary" {
                let offset = $start_offsets | get ($c.index - 1) | format_chapter_duration
                let chapter_components = $c.title | parse_chapter_title
                # todo Handle parts.
                $"* ($chapter_components.chapter) | ($chapter_components.chapter_title) | ($offset)"
            } else if $format == "debug" {
                {
                    index: $c.index
                    title: $c.title
                    duration: $c.duration
                    duration_millis: ($c.duration | format duration ms)
                    chapters_txt_start_offset: ($start_offsets | get $c.index | format_chapter_duration)
                    musicbrainz_length: $"($hours):($minutes):($seconds)"
                }
            }
        }
        | (
            let i = $in;
            if $format == "debug" {
                $i | print
            } else {
                $i | print --raw
            }
        )
    )
}
