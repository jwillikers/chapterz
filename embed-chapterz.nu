#!/usr/bin/env nu

use std log

use chapterz.nu *

# Embed chapters in an M4B file from an Audible ASIN, a MusicBrainz Release ID, or a chapters.txt file.
def main [
  m4b: path # The M4B audiobook in which to embed the chapters
  input: string # The source of the chapters
  --combine-chapter-parts # Combine chapters split into multiple parts into individual chapters. Only works for chapters titled according to the MusicBrainz Audiobook style guideline.
]: {
    let input_type = (
        if ($input | path parse | get stem) == "chapters" and ($input | path parse | get extension) == "txt" {
          "chapters.txt"
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
        if $input_type == "chapters.txt" {
            null
        } else if $input_type == "ASIN" {
            http get $"https://api.audnex.us/books/($input)/chapters"
            | get chapters
            | enumerate
            | each {|c|
                {
                    index: $c.index
                    title: $c.item.title
                    start_offset: ($c.item.startOffsetMs | into duration --unit ms)
                }
            }
        } else if $input_type == "MusicBrainz" {
            let chapters = (
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
            let chapters = (
              if $combine_chapter_parts {
                $chapters | combine_chapter_parts
              } else {
                $chapters
              }
            )
            let start_offsets = $chapters | get duration | lengths_to_start_offsets
            (
                $chapters
                | each {|c|
                    {
                        index: $c.index
                        title: $c.title
                        start_offset: ($start_offsets | get $c.index)
                    }
                }
            )
        }
    )

    let chapters_txt = (
        if $input_type == "chapters.txt" {
            $input
        } else if $input_type in ["ASIN" "MusicBrainz"] {
            mktemp --suffix .txt chapters.XXXXXX
        }
    )

    if $input_type in ["ASIN" "MusicBrainz"] {
        $chapters | each {|c|
            $"($c.start_offset | format_chapter_duration) ($c.title)"
        } | save --force $chapters_txt
    }

    ^tone tag --meta-chapters-file $chapters_txt $m4b

    if $input_type in ["ASIN" "MusicBrainz"] {
        rm $chapters_txt
    }
}
