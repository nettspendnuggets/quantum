+-OVERVIEW----------------------------------+
| quantum computing simulation lib written  |
| in luau                                   |
+-USAGE-------------------------------------+
| quantum.luau is the main file, require    |
| it.                                       |
+-STYLE-------------------------------------+
| GENERAL:                                  |
| - use tabs, spaces are janky to work with |
| - when you want to make a sub-table in a  |
| parent table, do this:                    |
| local parent = {}                         |
| local child = {}                          |
| parent.child = child                      |
|                                           |
| NAMING SCHEME:                            |
|               + GENERALS +                |
| - use snake case                          |
|                                           |
|                + PREFIX +                 |
| - m: supports multiple qubits             |
| - t: supports topological based           |
|                                           |
|                + SUFFIX +                 |
| - _ex: extra/expanded version of function |
+-CREDITS-----------------------------------+
| made by: axtr       > @axtrct             |
|          jiface     > @ssynical           |
|          plusgiant5 > @plusgiant5         |
|                                           |
|    used: greg hewgill's picomath          |
+-------------------------------------------+
