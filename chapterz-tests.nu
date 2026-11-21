#!/usr/bin/env nu

use std assert

use chapterz.nu *

def test_lengths_to_start_offsets [] {
  assert equal ([] | lengths_to_start_offsets) []
  assert equal ([5min] | lengths_to_start_offsets) [0ms]
  assert equal ([30sec 5min 1hr 2ms] | lengths_to_start_offsets) [0ms 30sec 330sec 3930sec]
}

def test_format_chapter_duration [] {
  assert equal (0ms | format_chapter_duration) "00:00:00.000"
  assert equal (1ms | format_chapter_duration) "00:00:00.001"
  assert equal (59999ms | format_chapter_duration) "00:00:59.999"
  assert equal (1min | format_chapter_duration) "00:01:00.000"
  assert equal (3723004ms | format_chapter_duration) "01:02:03.004"
  assert equal (100hr | format_chapter_duration) "100:00:00.000"
}

def test_format_musicbrainz_length [] {
  assert equal (0ms | format_musicbrainz_length) "00:00:00"
  assert equal (1499ms | format_musicbrainz_length) "00:00:01"
  assert equal (1500ms | format_musicbrainz_length) "00:00:02"
  assert equal (3723004ms | format_musicbrainz_length) "01:02:03"
  # Rounding up carries into the minutes and hours.
  assert equal (59500ms | format_musicbrainz_length) "00:01:00"
  assert equal (3599500ms | format_musicbrainz_length) "01:00:00"
}

def test_detect_input_type [] {
  assert equal ("book.m4b" | detect_input_type) "m4b"
  assert equal ("/path/to/My Audiobook.m4b" | detect_input_type) "m4b"
  assert equal ("chapters.txt" | detect_input_type) "chapters.txt"
  assert equal ("some/dir/chapters.txt" | detect_input_type) "chapters.txt"
  assert equal ("9219a403-d530-4f4d-ab4a-19e4be647a0e" | detect_input_type) "MusicBrainz"
  assert equal ("B0036S4B2G" | detect_input_type) "ASIN"
  assert equal ("notes.txt" | detect_input_type) null
  assert equal ("" | detect_input_type) null
  assert equal ("abc" | detect_input_type) null
}

def test_chapters_from_musicbrainz_release_media [] {
  let media = [
    {
      tracks: [
        {title: "Opening Credits" length: 30069}
        {title: "Chapter 1" length: 1144834}
      ]
    }
    {
      tracks: [
        {title: "Chapter 2" length: 1148453}
        {title: "Closing Credits" length: 7191}
      ]
    }
  ]
  let expected = [
    "00:00:00.000 Opening Credits"
    "00:00:30.069 Chapter 1"
    "00:19:34.903 Chapter 2"
    "00:38:43.356 Closing Credits"
  ] | str join "\n"
  assert equal ($media | chapters_from_musicbrainz_release_media) $expected
}

def test_round_to_second_using_cumulative_offset_edge_cases [] {
  assert equal ([] | round_to_second_using_cumulative_offset) []
  assert equal ([10sec 20sec] | round_to_second_using_cumulative_offset) [10sec 20sec]
  # Ties round down when there is no accumulated offset.
  assert equal ([500ms] | round_to_second_using_cumulative_offset) [0sec]
  # The accumulated offset is kept from drifting from the total.
  let durations = [1400ms 1400ms 1400ms 1400ms 1400ms]
  let rounded = $durations | round_to_second_using_cumulative_offset
  assert equal $rounded [1sec 2sec 1sec 2sec 1sec]
  assert equal ($rounded | math sum) 7sec
}

def test_round_to_second_using_cumulative_offset [] {
  let durations = [
    30069ms
    7191ms
    1144834ms
    1148453ms
    1005383ms
    340334ms
    1055909ms
    889571ms
    1210090ms
    1239241ms
    554999ms
    727045ms
    369422ms
    502728ms
    # 1529081ms
    # 770116ms
    # 596937ms
    # 608757ms
    # 463980ms
    # 1105896ms
    # 1235574ms
    # 70392ms
    # 95833ms
  ]
  let expected = [
    30sec # Down cumulative offset: -69
    7sec # Down cumulative offset: -191 - 69 = -260
    1145sec # Up (1145000 - 1144834 = 166) cumulative offset: (-260 + 166 = -94)
    1149sec # Up (1149000 - 1148453 = 547) cumulative offset: (-94 + 547 = 453)
    1005sec # Down (1005000 - 1005383 = -383) cumulative offset: (453 + -383 = 70)
    340sec # Down (340000 - 340334 = -334) cumulative offset: (70 + -334 = -264)
    1056sec # Up (1056000 - 1055909 = 91) cumulative offset: (-264 + 91 = -173)
    890sec # Up (890000 - 889571 = 429) cumulative offset: (-173 + 429 = 256)
    1210sec # Down (1210000 - 1210090 = -90) cumulative offset: (256 + -90 = 166)
    1239sec # Down (1239000 - 1239241 = -241) cumulative offset: (166 + -241 = -75)
    555sec # Up (555000 - 554999 = 1) cumulative offset: (-75 + 1 = -74)
    727sec # Down cumulative offset: (-74 + (727000 - 727045) = -119)
    370sec # Up cumulative offset: (-119 + (370000 - 369422) = 459)
    502sec # Down cumulative offset: (459 + (502000 - 502728) = -269)
    # 1529081ms
    # 770116ms
    # 596937ms
    # 608757ms
    # 463980ms
    # 1105896ms
    # 1235574ms
    # 70392ms
    # 95833ms
  ]
  assert equal ($durations | round_to_second_using_cumulative_offset) $expected
}

def test_has_default_chapters_audible [] {
  let chapters = [
    [index title duration];
    [1 "Chapter 1" 30069ms]
    [2 "Chapter 2" 7191ms]
    [3 "Chapter 3" 1144834ms]
    [4 "Chapter 4" 1148453ms]
    [5 "Chapter 5" 340334ms]
  ]
  assert equal ($chapters | has_default_chapters) true

  let chapters = [
    [index title duration];
    [1 "Chapter 1" 30069ms]
    [2 "Chapter 2" 7191ms]
    [3 "Chapter 3" 1144834ms]
    [4 "Chapter 4" 1148453ms]
    [5 "Epilogue / Closing Credits" 340334ms]
  ]
  assert equal ($chapters | has_default_chapters) false
}

def test_has_default_chapters_libro_fm [] {
  let chapters = [
    [index title duration];
    [1 "Hogfather - Track 001" 30069ms]
    [2 "Hogfather - Track 002" 7191ms]
    [3 "Hogfather - Track 003" 1144834ms]
    [4 "Hogfather - Track 004" 1148453ms]
    [5 "Hogfather - Track 005" 340334ms]
  ]
  assert equal ($chapters | has_default_chapters) true

  let chapters = [
    [index title duration];
    [1 "Hogfather - Track 001" 30069ms]
    [2 "Chapter 2" 7191ms]
    [3 "Hogfather - Track 003" 1144834ms]
    [4 "Hogfather - Track 004" 1148453ms]
    [5 "Hogfather - Track 005" 340334ms]
  ]
  assert equal ($chapters | has_default_chapters) false
}

def test_has_default_chapters_empty [] {
  assert equal ([] | has_default_chapters) false
}

def test_has_default_chapters [] {
  test_has_default_chapters_empty
  test_has_default_chapters_audible
  test_has_default_chapters_libro_fm
}

def test_rename_chapters_audible [] {
  let chapters = [
    [index title duration];
    [1 "Prologue" 5min]
    [2 "Chapter 1" 15min]
    [3 "Chapter 2" 1144834ms]
    [4 "Chapter 3" 1148453ms]
    [5 "Epilogue" 30min]
  ]
  let expected = [
    [index title duration];
    [1 "Opening Credits / Chapter 1" 5min]
    [2 "Chapter 2" 15min]
    [3 "Chapter 3" 1144834ms]
    [4 "Chapter 4" 1148453ms]
    [5 "Chapter 5 / Closing Credits" 30min]
  ]
  assert equal ($chapters | rename_chapters) $expected

  let chapters = [
    [index title duration];
    [1 "Chapter 1" 1155053ms]
    [2 "Chapter 2" 418842ms]
    [3 "Chapter 3" 1404064ms]
    [4 "Chapter 4" 538424ms]
    [5 "Chapter 5" 325212ms]
  ]
  let expected = [
    [index title duration];
    [1 "Opening Credits / Chapter 1" 1155053ms]
    [2 "Chapter 2" 418842ms]
    [3 "Chapter 3" 1404064ms]
    [4 "Chapter 4" 538424ms]
    [5 "Chapter 5 / Closing Credits" 325212ms]
  ]
  assert equal ($chapters | rename_chapters) $expected
}

def test_rename_chapters_libro_fm [] {
  let chapters = [
    [index title duration];
    [1 "Hogfather - Track 001" 5min]
    [2 "Hogfather - Track 002" 7191ms]
    [3 "Hogfather - Track 003" 1144834ms]
    [4 "Hogfather - Track 004" 1148453ms]
    [5 "Hogfather - Track 005" 30min]
  ]
  let expected = [
    [index title duration];
    [1 "Opening Credits / Chapter 1" 5min]
    [2 "Chapter 2" 7191ms]
    [3 "Chapter 3" 1144834ms]
    [4 "Chapter 4" 1148453ms]
    [5 "Chapter 5 / Closing Credits" 30min]
  ]
  assert equal ($chapters | rename_chapters) $expected
}

def test_rename_chapters_separate_opening_credits [] {
  let chapters = [
    [index title duration];
    [1 "Chapter 1" 44sec]
    [2 "Chapter 2" 15min]
    [3 "Chapter 3" 1144834ms]
    [4 "Chapter 4" 1148453ms]
    [5 "Chapter 5" 30min]
  ]
  let expected = [
    [index title duration];
    [1 "Opening Credits" 44sec]
    [2 "Chapter 1" 15min]
    [3 "Chapter 2" 1144834ms]
    [4 "Chapter 3" 1148453ms]
    [5 "Chapter 4 / Closing Credits" 30min]
  ]
  assert equal ($chapters | rename_chapters) $expected
}

def test_rename_chapters_separate_end_credits [] {
  let chapters = [
    [index title duration];
    [1 "Chapter 1" 5min]
    [2 "Chapter 2" 15min]
    [3 "Chapter 3" 1144834ms]
    [4 "Chapter 4" 1148453ms]
    [5 "Chapter 5" 30sec]
  ]
  let expected = [
    [index title duration];
    [1 "Opening Credits / Chapter 1" 5min]
    [2 "Chapter 2" 15min]
    [3 "Chapter 3" 1144834ms]
    [4 "Chapter 4" 1148453ms]
    [5 "Closing Credits" 30sec]
  ]
  assert equal ($chapters | rename_chapters) $expected
}

def test_rename_chapters_separate_credits [] {
  let chapters = [
    [index title duration];
    [1 "Chapter 1" 44sec]
    [2 "Chapter 2" 15min]
    [3 "Chapter 3" 1144834ms]
    [4 "Chapter 4" 1148453ms]
    [5 "Chapter 5" 15sec]
  ]
  let expected = [
    [index title duration];
    [1 "Opening Credits" 44sec]
    [2 "Chapter 1" 15min]
    [3 "Chapter 2" 1144834ms]
    [4 "Chapter 3" 1148453ms]
    [5 "Closing Credits" 15sec]
  ]
  assert equal ($chapters | rename_chapters) $expected
}

def test_rename_chapters_offset [] {
  let chapters = [
    [index title duration];
    [1 "Hogfather - Track 001" 5min]
    [2 "Hogfather - Track 002" 7191ms]
    [3 "Hogfather - Track 003" 1144834ms]
    [4 "Hogfather - Track 004" 1148453ms]
    [5 "Hogfather - Track 005" 30min]
  ]
  let expected = [
    [index title duration];
    [1 "Opening Credits / Prologue" 5min]
    [2 "Chapter 1" 7191ms]
    [3 "Chapter 2" 1144834ms]
    [4 "Chapter 3" 1148453ms]
    [5 "Chapter 4 / Closing Credits" 30min]
  ]
  assert equal ($chapters | rename_chapters --offset 1) $expected

  let chapters = [
    [index title duration];
    [1 "Hogfather - Track 001" 29sec]
    [2 "Hogfather - Track 002" 7191ms]
    [3 "Hogfather - Track 003" 7191ms]
    [4 "Hogfather - Track 004" 1144834ms]
    [5 "Hogfather - Track 005" 1148453ms]
    [6 "Hogfather - Track 006" 30min]
  ]
  let expected = [
    [index title duration];
    [1 "Opening Credits" 29sec]
    [2 "Chapter -1" 7191ms]
    [3 "Epigraph" 7191ms]
    [4 "Chapter 1" 1144834ms]
    [5 "Chapter 2" 1148453ms]
    [6 "Chapter 3 / Closing Credits" 30min]
  ]
  assert equal ($chapters | rename_chapters --offset 3) $expected
}

def test_rename_chapters_prefix [] {
  let chapters = [
    [index title duration];
    [1 "Hogfather - Track 001" 5min]
    [2 "Hogfather - Track 002" 7191ms]
    [3 "Hogfather - Track 003" 1144834ms]
    [4 "Hogfather - Track 004" 1148453ms]
    [5 "Hogfather - Track 005" 30min]
  ]
  let expected = [
    [index title duration];
    [1 'Opening Credits / Part One: "ABC", Chapter 1' 5min]
    [2 'Part One: "ABC", Chapter 2' 7191ms]
    [3 'Part One: "ABC", Chapter 3' 1144834ms]
    [4 'Part One: "ABC", Chapter 4' 1148453ms]
    [5 'Part One: "ABC", Chapter 5 / Closing Credits' 30min]
  ]
  assert equal ($chapters | rename_chapters --prefix 'Part One: "ABC", ') $expected
}

def test_rename_chapters_suffix [] {
  let chapters = [
    [index title duration];
    [1 "Hogfather - Track 001" 5min]
    [2 "Hogfather - Track 002" 7191ms]
    [3 "Hogfather - Track 003" 1144834ms]
    [4 "Hogfather - Track 004" 1148453ms]
    [5 "Hogfather - Track 005" 30min]
  ]
  let expected = [
    [index title duration];
    [1 'Opening Credits / Chapter 1: ""' 5min]
    [2 'Chapter 2: ""' 7191ms]
    [3 'Chapter 3: ""' 1144834ms]
    [4 'Chapter 4: ""' 1148453ms]
    [5 'Chapter 5: "" / Closing Credits' 30min]
  ]
  assert equal ($chapters | rename_chapters --suffix ': ""') $expected
}

def test_rename_chapters_prefix_suffix [] {
  let chapters = [
    [index title duration];
    [1 "Hogfather - Track 001" 5sec]
    [2 "Hogfather - Track 002" 7191ms]
    [3 "Hogfather - Track 003" 1144834ms]
    [4 "Hogfather - Track 004" 1148453ms]
    [5 "Hogfather - Track 005" 30min]
  ]
  let expected = [
    [index title duration];
    [1 "Opening Credits" 5sec]
    [2 'Part One: "ABC", Chapter 1: ""' 7191ms]
    [3 'Part One: "ABC", Chapter 2: ""' 1144834ms]
    [4 'Part One: "ABC", Chapter 3: ""' 1148453ms]
    [5 'Part One: "ABC", Chapter 4: "" / Closing Credits' 30min]
  ]
  assert equal ($chapters | rename_chapters --prefix 'Part One: "ABC", ' --suffix ': ""') $expected
}

def test_rename_chapters_chapter_word [] {
  let chapters = [
    [index title duration];
    [1 "Hogfather - Track 001" 5min]
    [2 "Hogfather - Track 002" 7191ms]
    [3 "Hogfather - Track 003" 1144834ms]
    [4 "Hogfather - Track 004" 1148453ms]
    [5 "Hogfather - Track 005" 30min]
  ]
  let expected = [
    [index title duration];
    [1 "Opening Credits / Part 1" 5min]
    [2 "Part 2" 7191ms]
    [3 "Part 3" 1144834ms]
    [4 "Part 4" 1148453ms]
    [5 "Part 5 / Closing Credits" 30min]
  ]
  assert equal ($chapters | rename_chapters --chapter-word "Part") $expected
}

def test_rename_chapters_single_chapter [] {
  let chapters = [
    [index title duration];
    [1 "Chapter 1" 5hr]
  ]
  assert equal ($chapters | rename_chapters) $chapters
}

def test_rename_chapters_unsorted [] {
  let chapters = [
    [index title duration];
    [3 "Chapter 3" 15min]
    [1 "Chapter 1" 5min]
    [2 "Chapter 2" 15min]
  ]
  let expected = [
    [index title duration];
    [1 "Opening Credits / Chapter 1" 5min]
    [2 "Chapter 2" 15min]
    [3 "Chapter 3 / Closing Credits" 15min]
  ]
  assert equal ($chapters | rename_chapters) $expected
}

def test_rename_chapters_prologue [] {
  let chapters = [
    [index title duration];
    [1 "Chapter 1" 30sec]
    [2 "Chapter 2" 5min]
    [3 "Chapter 3" 15min]
    [4 "Chapter 4" 15min]
  ]
  let expected = [
    [index title duration];
    [1 "Opening Credits" 30sec]
    [2 "Prologue" 5min]
    [3 "Chapter 1" 15min]
    [4 "Chapter 2 / Closing Credits" 15min]
  ]
  assert equal ($chapters | rename_chapters --offset 2) $expected
}

def test_rename_chapters_requires_one_based_indices [] {
  let chapters = [
    [index title duration];
    [0 "Chapter 1" 5min]
    [1 "Chapter 2" 15min]
  ]
  assert error {|| $chapters | rename_chapters }
}

def test_rename_chapters [] {
  test_rename_chapters_single_chapter
  test_rename_chapters_unsorted
  test_rename_chapters_prologue
  test_rename_chapters_requires_one_based_indices
  test_rename_chapters_audible
  test_rename_chapters_libro_fm
  test_rename_chapters_separate_opening_credits
  test_rename_chapters_separate_end_credits
  test_rename_chapters_separate_credits
  test_rename_chapters_offset
  test_rename_chapters_prefix
  test_rename_chapters_suffix
  test_rename_chapters_prefix_suffix
  test_rename_chapters_chapter_word
}

def test_parse_chapter_title_all_parts [] {
  let chapter = 'Part One: "The First Part", Chapter 1: "The First Chapter", Part 1'
  let expected = {
    part: "Part One"
    part_title: "The First Part"
    chapter: "Chapter 1"
    chapter_title: "The First Chapter"
    chapter_part: "Part 1"
  }
  assert equal ($chapter | parse_chapter_title) $expected
}

def test_parse_chapter_title_chapter_only [] {
  let chapter = 'Chapter 1'
  let expected = {
    part: null
    part_title: ""
    chapter: "Chapter 1"
    chapter_title: ""
    chapter_part: null
  }
  assert equal ($chapter | parse_chapter_title) $expected
}

def test_parse_chapter_title_chapter_with_name [] {
  let chapter = 'Chapter 1: "First Chapter"'
  let expected = {
    part: null
    part_title: ""
    chapter: "Chapter 1"
    chapter_title: "First Chapter"
    chapter_part: null
  }
  assert equal ($chapter | parse_chapter_title) $expected
}

def test_parse_chapter_title_chapter_part [] {
  let chapter = 'Chapter 1, Part 1'
  let expected = {
    part: null
    part_title: ""
    chapter: "Chapter 1"
    chapter_title: ""
    chapter_part: "Part 1"
  }
  assert equal ($chapter | parse_chapter_title) $expected
}

def test_parse_chapter_title_part_chapter [] {
  let chapter = 'Part One, Chapter 1'
  let expected = {
    part: "Part One"
    part_title: ""
    chapter: "Chapter 1"
    chapter_title: ""
    chapter_part: null
  }
  assert equal ($chapter | parse_chapter_title) $expected
}

def test_parse_chapter_title_opening_credits [] {
  let chapter = 'Opening Credits'
  let expected = {
    part: null
    part_title: ""
    chapter: "Opening Credits"
    chapter_title: ""
    chapter_part: null
  }
  assert equal ($chapter | parse_chapter_title) $expected
}

def test_parse_chapter_title_opening_credits_chapter_one [] {
  let chapter = 'Opening Credits / Chapter 1'
  let expected = {
    part: null
    part_title: ""
    chapter: "Opening Credits / Chapter 1"
    chapter_title: ""
    chapter_part: null
  }
  assert equal ($chapter | parse_chapter_title) $expected
}

def test_parse_chapter_title [] {
  test_parse_chapter_title_all_parts
  test_parse_chapter_title_chapter_only
  test_parse_chapter_title_chapter_with_name
  test_parse_chapter_title_chapter_part
  test_parse_chapter_title_part_chapter
  test_parse_chapter_title_opening_credits
  test_parse_chapter_title_opening_credits_chapter_one
}

def test_combine_chapter_parts_none [] {
  let input = [
    [index title duration];
    [1 "Chapter 1" 30069ms]
    [2 "Chapter 2" 7191ms]
    [3 "Chapter 3" 1144834ms]
    [4 "Chapter 4" 1148453ms]
    [5 "Chapter 5" 340334ms]
  ]
  let expected = [
    [index title duration];
    [1 "Chapter 1" 30069ms]
    [2 "Chapter 2" 7191ms]
    [3 "Chapter 3" 1144834ms]
    [4 "Chapter 4" 1148453ms]
    [5 "Chapter 5" 340334ms]
  ]
  assert equal ($input | combine_chapter_parts) $expected
}

def test_combine_chapter_parts_combine_one_chapter [] {
  let input = [
    [index title duration];
    [1 "Chapter 1" 30069ms]
    [2 "Chapter 2, Part 1" 7191ms]
    [3 "Chapter 2, Part 2" 1144834ms]
    [4 "Chapter 3" 1148453ms]
    [5 "Chapter 4" 340334ms]
  ]
  let expected = [
    [index title duration];
    [1 "Chapter 1" 30069ms]
    [2 "Chapter 2" 1152025ms]
    [3 "Chapter 3" 1148453ms]
    [4 "Chapter 4" 340334ms]
  ]
  assert equal ($input | combine_chapter_parts) $expected
}

def test_combine_chapter_parts_combine_two_chapters [] {
  let input = [
    [index title duration];
    [1 "Chapter 1" 30069ms]
    [2 "Chapter 2, Part 1" 7191ms]
    [3 "Chapter 2, Part 2" 1144834ms]
    [4 "Chapter 3, Part 1" 1148453ms]
    [5 "Chapter 3, Part 2" 340334ms]
  ]
  let expected = [
    [index title duration];
    [1 "Chapter 1" 30069ms]
    [2 "Chapter 2" 1152025ms]
    [3 "Chapter 3" 1488787ms]
  ]
  assert equal ($input | combine_chapter_parts) $expected
}

def test_combine_chapter_parts_combine_one_chapter_three_parts [] {
  let input = [
    [index title duration];
    [1 "Part 1, Part 1" 30069ms]
    [2 "Part 1, Part 2" 7191ms]
    [3 "Part 1, Part 3" 1144834ms]
    [4 "Part 2" 1148453ms]
    [5 "Part 3" 340334ms]
  ]
  let expected = [
    [index title duration];
    [1 "Part 1" 1182094ms]
    [2 "Part 2" 1148453ms]
    [3 "Part 3" 340334ms]
  ]
  assert equal ($input | combine_chapter_parts) $expected
}

def test_combine_chapter_parts_non_one_based_index [] {
  let input = [
    [index title duration];
    [0 "Chapter 1, Part 1" 1min]
    [1 "Chapter 1, Part 2" 2min]
    [2 "Chapter 2" 3min]
  ]
  let expected = [
    [index title duration];
    [0 "Chapter 1" 3min]
    [1 "Chapter 2" 3min]
  ]
  assert equal ($input | combine_chapter_parts) $expected
}

def test_combine_chapter_parts_non_adjacent [] {
  # Only consecutive parts of the same chapter are combined.
  let input = [
    [index title duration];
    [1 "Chapter 1, Part 1" 1min]
    [2 "Chapter 2" 2min]
    [3 "Chapter 1, Part 2" 3min]
  ]
  let expected = [
    [index title duration];
    [1 "Chapter 1" 1min]
    [2 "Chapter 2" 2min]
    [3 "Chapter 1" 3min]
  ]
  assert equal ($input | combine_chapter_parts) $expected
}

def test_combine_chapter_parts [] {
  test_combine_chapter_parts_non_one_based_index
  test_combine_chapter_parts_non_adjacent
  test_combine_chapter_parts_none
  test_combine_chapter_parts_combine_one_chapter
  test_combine_chapter_parts_combine_two_chapters
  test_combine_chapter_parts_combine_one_chapter_three_parts
}

def sample_chapters [] {
  [
    [index title duration];
    [1 "Opening Credits" 30069ms]
    [2 'Chapter 1: "The Beginning"' 1144834ms]
    [3 "Chapter 2" 1148453ms]
    [4 "Closing Credits" 7191ms]
  ]
}

def test_format_chapters_musicbrainz [] {
  let expected = [
    "1 Opening Credits (00:00:30)"
    '2 Chapter 1: "The Beginning" (00:19:05)'
    "3 Chapter 2 (00:19:08)"
    "4 Closing Credits (00:00:07)"
  ]
  assert equal (sample_chapters | format_chapters) $expected
  assert equal (sample_chapters | format_chapters --format musicbrainz) $expected
}

def test_format_chapters_chapters_txt [] {
  let expected = [
    "00:00:00.000 Opening Credits"
    '00:00:30.069 Chapter 1: "The Beginning"'
    "00:19:34.903 Chapter 2"
    "00:38:43.356 Closing Credits"
  ]
  assert equal (sample_chapters | format_chapters --format chapters.txt) $expected
}

def test_format_chapters_start_offsets_independent_of_index [] {
  # Start offsets come from the order of the chapters, not from their indices.
  let zero_based = sample_chapters | update index {|c| $c.index - 1 }
  assert equal (
    $zero_based | format_chapters --format chapters.txt
  ) (
    sample_chapters | format_chapters --format chapters.txt
  )
}

def test_format_chapters_tone [] {
  let expected = [
    [index start length title];
    [1 0 30069 "Opening Credits"]
    [2 30069 1144834 'Chapter 1: "The Beginning"']
    [3 1174903 1148453 "Chapter 2"]
    [4 2323356 7191 "Closing Credits"]
  ]
  assert equal (sample_chapters | format_chapters --format tone) $expected
}

def test_format_chapters_openlibrary [] {
  let expected = [
    "* Opening Credits |  | 00:00:00.000"
    "* Chapter 1 | The Beginning | 00:00:30.069"
    "* Chapter 2 |  | 00:19:34.903"
    "* Closing Credits |  | 00:38:43.356"
  ]
  assert equal (sample_chapters | format_chapters --format OpenLibrary) $expected
}

def test_format_chapters_debug [] {
  let actual = sample_chapters | format_chapters --format debug
  assert equal ($actual | length) 4
  assert equal ($actual | last) {
    index: 4
    title: "Closing Credits"
    duration: 7191ms
    duration_millis: "7191 ms"
    chapters_txt_start_offset: "00:38:43.356"
    musicbrainz_length: "00:00:07"
  }
}

def test_format_chapters_unsupported_format [] {
  assert error {|| sample_chapters | format_chapters --format bogus }
}

def test_format_chapters_empty [] {
  assert equal ([] | format_chapters --format chapters.txt) []
}

def test_format_chapters [] {
  test_format_chapters_musicbrainz
  test_format_chapters_chapters_txt
  test_format_chapters_start_offsets_independent_of_index
  test_format_chapters_tone
  test_format_chapters_openlibrary
  test_format_chapters_debug
  test_format_chapters_unsupported_format
  test_format_chapters_empty
}

def main [] {
  let tests = [
    {name: "lengths_to_start_offsets" test: {|| test_lengths_to_start_offsets }}
    {name: "format_chapter_duration" test: {|| test_format_chapter_duration }}
    {name: "format_musicbrainz_length" test: {|| test_format_musicbrainz_length }}
    {name: "detect_input_type" test: {|| test_detect_input_type }}
    {name: "chapters_from_musicbrainz_release_media" test: {|| test_chapters_from_musicbrainz_release_media }}
    {name: "round_to_second_using_cumulative_offset" test: {|| test_round_to_second_using_cumulative_offset }}
    {name: "round_to_second_using_cumulative_offset_edge_cases" test: {|| test_round_to_second_using_cumulative_offset_edge_cases }}
    {name: "has_default_chapters" test: {|| test_has_default_chapters }}
    {name: "rename_chapters" test: {|| test_rename_chapters }}
    {name: "parse_chapter_title" test: {|| test_parse_chapter_title }}
    {name: "combine_chapter_parts" test: {|| test_combine_chapter_parts }}
    {name: "format_chapters" test: {|| test_format_chapters }}
  ]
  let failures = $tests | each {|t|
    try {
      do $t.test
      print $"(ansi green)PASS(ansi reset) ($t.name)"
      null
    } catch {|err|
      print --stderr $"(ansi red)FAIL(ansi reset) ($t.name)\n($err.rendered)"
      $t.name
    }
  }
  if ($failures | is-not-empty) {
    print --stderr $"($failures | length) of ($tests | length) test groups failed: ($failures | str join ', ')"
    exit 1
  }
  print "All tests passed!"
}
