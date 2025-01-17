#!/usr/bin/env nu

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

# Print out the chapters for an audiobook in the format used when adding the track list to MusicBrainz.
#
# Takes the path to an M4B file, an Audible ASIN, or a MusicBrainz Release ID.
#
def main [
    input: string
    format: string = "musicbrainz" # Can also be "chapters.txt" or "debug"
    # --chapter-offset: int = 0 # The number to use as the first chapter number
    --round # Force rounding for chapters.txt
]: {
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
                    index: $c.index
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
                    index: $c.index
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
                $"($c.index + 1) ($c.title) \(($hours):($minutes):($seconds)\)"
            } else if $format == "chapters.txt" {
                let offset = $start_offsets | get $c.index | format_chapter_duration
                $"($offset) ($c.title)"
            } else if $format == "debug" {
                {
                    index: $c.index
                    start_offset: ($start_offsets | get $c.index | format_chapter_duration)
                    length: $"($hours):($minutes):($seconds)"
                    title: $c.title
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
