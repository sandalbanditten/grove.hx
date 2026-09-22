Feature: Color entry labels from an Entry palette

  Scenario: Color each entry kind from its type rule
    Given a Workspace containing entries
      | kind        | path        | target     |
      | file        | anchor.txt  |            |
      | directory   | folder      |            |
      | file link   | file-link   | anchor.txt |
      | broken link | broken-link | missing    |
    And "anchor.txt" is Active
    And Grove reads these Entry colors
      | key | code            |
      | di  | 0;38;2;10;20;30 |
      | fi  | 0;38;2;40;50;60 |
      | ln  | 3;38;2;70;80;90 |
      | or  | 0;38;2;11;22;33 |
    When Helix starts with Grove in that Workspace
    Then these rows use Entry colors
      | row            | color    |
      | Workspace root | 10 20 30 |
      | folder         | 10 20 30 |
      | anchor.txt     | 40 50 60 |
      | file-link      | 70 80 90 |
    And "file-link" label is italic
    And "anchor.txt" label is not italic
    And "broken-link" uses the broken-link icon and error foreground

  Scenario: Prefer the longest matching pattern and leave directories to their type
    Given a Workspace containing entries
      | kind      | path      |
      | file      | README.md |
      | file      | notes.md  |
      | file      | main.rs   |
      | directory | docs.md   |
    And "main.rs" is Active
    And Grove reads these Entry colors
      | key        | code            |
      | di         | 0;38;2;10;20;30 |
      | fi         | 0;38;2;40;50;60 |
      | *.md       | 0;38;2;70;80;90 |
      | *README.md | 0;38;2;11;22;33 |
    When Helix starts with Grove in that Workspace
    Then these rows use Entry colors
      | row       | color    |
      | README.md | 11 22 33 |
      | notes.md  | 70 80 90 |
      | main.rs   | 40 50 60 |
      | docs.md   | 10 20 30 |

  Scenario: Keep every label naming its entry while Git marks the changes
    Given a Workspace containing entries
      | kind      | path               |
      | file      | anchor.txt         |
      | file      | modified.txt       |
      | directory | touched            |
      | file      | touched/inside.txt |
    And "anchor.txt" is Active
    And Git reports statuses
      | path               | status   |
      | modified.txt       | modified |
      | touched/inside.txt | modified |
    And Grove reads these Entry colors
      | key | code            |
      | di  | 0;38;2;10;20;30 |
      | fi  | 1;38;2;40;50;60 |
    When Helix starts with Grove in that Workspace
    Then these rows use Entry colors
      | row            | color    |
      | Workspace root | 10 20 30 |
      | touched        | 10 20 30 |
      | anchor.txt     | 40 50 60 |
      | modified.txt   | 40 50 60 |
    And "modified.txt" label is bold
    And "modified.txt" carries a modified Git mark
    And "touched" carries a modified Git mark
    And "anchor.txt" carries no Git mark
    When the "touched" directory is expanded
    Then "touched/inside.txt" carries a modified Git mark
    And these rows use Entry colors
      | row                | color    |
      | touched/inside.txt | 40 50 60 |

  Scenario: Read the palette from the environment
    Given a Workspace containing entries
      | path       |
      | anchor.txt |
      | notes.md   |
    And "anchor.txt" is Active
    And the environment sets LS_COLORS to "fi=0;38;2;40;50;60:*.md=0;38;2;1;2;3"
    And the environment sets EZA_COLORS to "*.md=0;38;2;70;80;90"
    And Grove settings
      | setting   | value       |
      | ls-colors | environment |
    When Helix starts with Grove in that Workspace
    Then these rows use Entry colors
      | row        | color    |
      | anchor.txt | 40 50 60 |
      | notes.md   | 70 80 90 |

  Scenario Outline: Keep Theme role colors without a usable palette
    Given a Workspace containing entries
      | path       |
      | anchor.txt |
    And "anchor.txt" is Active
    And Grove settings
      | setting   | value       |
      | ls-colors | <ls-colors> |
    When Helix starts with Grove in that Workspace
    Then "anchor.txt" uses the theme text foreground

    Examples:
      | ls-colors   |
      | disabled    |
      | environment |

  Scenario: Reject an invalid Entry palette configuration
    Given Grove settings
      | setting   | value |
      | ls-colors | 42    |
    When Grove startup is attempted
    Then Grove startup reports "invalid Grove LS_COLORS"
