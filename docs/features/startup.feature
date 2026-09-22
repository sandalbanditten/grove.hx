Feature: Start Grove

  Scenario: Start in an empty Workspace
    Given a Workspace containing entries
      | path |
    When Helix starts with Grove in that Workspace
    Then the File tree shows "Workspace root"
    When Grove is focused
    Then "Workspace root" has Cursor
    When Grove receives "n"
    Then the native prompt is "New file in ./"
    When the prompt receives "first.txt"
    Then "first.txt" exists as an empty file
    And the File tree already shows "first.txt"

  Scenario Outline: Reject invalid Grove settings
    Given Grove settings
      | setting   | value   |
      | <setting> | <value> |
    When Grove startup is attempted
    Then Grove startup reports "<message>"

    Examples:
      | setting    | value       | message                        |
      | side       | middle      | invalid Grove side             |
      | width      | 15          | invalid Grove width            |
      | width      | wide text   | invalid Grove width            |
      | icons      | non-boolean | Grove icons must be a boolean  |
      | guides     | non-boolean | Grove guides must be a boolean |
      | visibility | middle      | invalid Grove visibility       |
      | sort       | middle      | invalid Grove sort             |

  Scenario: Reject a second start
    Given Grove starts twice
    When Grove startup is attempted
    Then Grove startup reports "Grove has already started"

  Scenario Outline: Accept an action before deferred startup completes
    Given a Workspace containing entries
      | path       |
      | anchor.txt |
    And "anchor.txt" is Active
    And Grove settings
      | setting    | value   |
      | visibility | focused |
    And Grove calls "<action>" during Helix initialization
    When Helix starts with Grove in that Workspace
    Then Grove is Docked on the "left" at width 32
    And "anchor.txt" <cursor>

    Examples:
      | action                    | cursor             |
      | grove-focus!              | has Cursor         |
      | grove-visibility-toggle!  | has no Cursor mark |

  Scenario: Start without an Active file
    Given a Workspace containing entries
      | kind | path       |
      | file | anchor.txt |
    When Helix starts with Grove in that Workspace
    Then the File tree shows "anchor.txt"
    When the editor receives "i" while Grove is unfocused
    Then the active Editor view is in Insert mode

  Scenario: Open the Workspace on the Active file
    Given a Workspace containing entries
      | kind | path                   |
      | file | anchor.txt             |
      | file | outer/inner/active.txt |
    And "outer/inner/active.txt" is Active
    When Helix starts with Grove in that Workspace
    Then the File tree shows "outer/inner/active.txt"
    And "outer" remains expanded
    And "outer/inner" remains expanded
    And "outer/inner/active.txt" uses the Active file mark
    And "outer/inner/active.txt" has no Cursor mark
    When the editor receives "i" while Grove is unfocused
    Then the active Editor view is in Insert mode

  Scenario: Open the Workspace on every file Helix already holds
    Given a Workspace containing entries
      | kind | path                   |
      | file | anchor.txt             |
      | file | outer/inner/first.scm  |
      | file | other/deep/second.scm  |
      | file | untouched/third.scm    |
    And "outer/inner/first.scm" is Active
    And Helix also opens
      | path                  |
      | other/deep/second.scm |
    When Helix starts with Grove in that Workspace
    Then the File tree shows "outer/inner/first.scm"
    And the File tree shows "other/deep/second.scm"
    And the File tree does not show "untouched/third.scm"
    And "outer/inner/first.scm" has no Cursor mark

  Scenario: Open a tall Workspace scrolled to the Active file
    Given a Workspace containing entries
      | kind | path                        | count |
      | file | outer/inner/item-{:02d}.txt | 40    |
    And "outer/inner/item-39.txt" is Active
    When Helix starts with Grove in that Workspace
    Then the File tree shows "outer/inner/item-39.txt"
    And "outer/inner/item-39.txt" has no Cursor mark

  Scenario: Start Docked without taking editor focus
    Given a Workspace containing entries
      | kind      | path              |
      | file      | anchor.txt        |
      | directory | folder            |
      | file      | folder/inside.txt |
    And "anchor.txt" is Active
    When Helix starts with Grove in that Workspace
    Then the File tree shows "anchor.txt"
    And Grove is Docked on the "left" at width 32
    When the editor receives "i" while Grove is unfocused
    Then the active Editor view is in Insert mode

  Scenario Outline: Reload Helix configuration with Grove running
    Given a Workspace containing entries
      | path       |
      | anchor.txt |
    And "anchor.txt" is Active
    And Helix binds <key> to configuration reload
    When Helix starts with Grove in that Workspace
    And Grove <action>
    And Helix reloads configuration 3 times through "<method>" with reload key <key>
    Then the File tree shows "anchor.txt"
    When Grove is focused
    Then "anchor.txt" has Cursor
    When Grove receives "n"
    Then the native prompt is "New file in ./"
    When the prompt receives "recovered.txt"
    Then "recovered.txt" exists as an empty file
    And the File tree shows "recovered.txt"
    When the editor inserts "saved after reload" and saves
    Then the content of "recovered.txt" starts with "saved after reload"
    When "appeared.txt" is created
    Then the File tree shows "appeared.txt"
    When Helix exits
    Then Helix exits normally

    Examples:
      | method         | action            | key |
      | command prompt | is focused        | C-x |
      | command prompt | receives "Escape" | C-z |
      | hotkey         | is focused        | C-x |
      | hotkey         | receives "Escape" | C-z |

  Scenario: Exit with Grove running
    Given a Workspace containing entries
      | path       |
      | anchor.txt |
    When Helix starts with Grove in that Workspace
    And Helix exits
    Then Helix exits normally
