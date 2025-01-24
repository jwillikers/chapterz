#!/usr/bin/env nu

use std assert

use chapterz.nu *

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
    [5 "Epilogue / End Credits" 340334ms]
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

def test_has_default_chapters [] {
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
    [5 "Chapter 5 / End Credits" 30min]
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
    [5 "Chapter 5 / End Credits" 325212ms]
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
    [5 "Chapter 5 / End Credits" 30min]
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
    [5 "Chapter 4 / End Credits" 30min]
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
    [5 "End Credits" 30sec]
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
    [5 "End Credits" 15sec]
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
    [5 "Chapter 4 / End Credits" 30min]
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
    [3 "Prologue" 7191ms]
    [4 "Chapter 1" 1144834ms]
    [5 "Chapter 2" 1148453ms]
    [6 "Chapter 3 / End Credits" 30min]
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
    [5 'Part One: "ABC", Chapter 5 / End Credits' 30min]
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
    [5 'Chapter 5: "" / End Credits' 30min]
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
    [5 'Part One: "ABC", Chapter 4: "" / End Credits' 30min]
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
    [5 "Part 5 / End Credits" 30min]
  ]
  assert equal ($chapters | rename_chapters --chapter-word "Part") $expected
}

def test_rename_chapters [] {
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
    part: ""
    part_title: ""
    chapter: "Chapter 1"
    chapter_title: ""
    chapter_part: ""
  }
  assert equal ($chapter | parse_chapter_title) $expected
}

def test_parse_chapter_title_chapter_with_name [] {
  let chapter = 'Chapter 1: "First Chapter"'
  let expected = {
    part: ""
    part_title: ""
    chapter: "Chapter 1"
    chapter_title: "First Chapter"
    chapter_part: ""
  }
  assert equal ($chapter | parse_chapter_title) $expected
}

def test_parse_chapter_title_chapter_part [] {
  let chapter = 'Chapter 1, Part 1'
  let expected = {
    part: ""
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
    chapter_part: ""
  }
  assert equal ($chapter | parse_chapter_title) $expected
}

def test_parse_chapter_title_opening_credits [] {
  let chapter = 'Opening Credits'
  let expected = {
    part: ""
    part_title: ""
    chapter: "Opening Credits"
    chapter_title: ""
    chapter_part: ""
  }
  assert equal ($chapter | parse_chapter_title) $expected
}

def test_parse_chapter_title_opening_credits_chapter_one [] {
  let chapter = 'Opening Credits / Chapter 1'
  let expected = {
    part: ""
    part_title: ""
    chapter: "Opening Credits / Chapter 1"
    chapter_title: ""
    chapter_part: ""
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

def main [] {
  test_round_to_second_using_cumulative_offset
  test_has_default_chapters
  test_rename_chapters
  test_parse_chapter_title
  echo "All tests passed!"
}
