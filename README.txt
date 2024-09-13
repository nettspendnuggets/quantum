+-OVERVIEW----------------------------------+-LICENSE-(MIT)---------------------------------------------------+
| quantum computing simulation lib written  | MIT License                                                     |
| in luau                                   |                                                                 |
+-USAGE-------------------------------------+ Copyright (c) 2024 axtrct                                       |
| quantum.luau is the main file, require    |                                                                 |
| it.                                       | Permission is hereby granted, free of charge, to any person     |
+-STYLE-------------------------------------+ obtaining a copy of this software and associated documentation  |
| GENERAL:                                  | files (the "Software"), to deal in the Software without         |
| - use tabs, spaces are janky to work with | restriction, including without limitation the right to use,     |
| - when you want to make a sub-table in a  | copy, modify, merge, publish, distribute, sublicense, and/or    |
| parent table, do this:                    | sell copies of the Software, and to permit persons to whom      |
| local parent = {}                         | the Software is furnished to do so, subject to the following    |
| local child = {}                          | conditions:                                                     |
| parent.child = child                      |                                                                 |
|                                           | The above copyright notice and this permission notice shall be  |
| NAMING SCHEME:                            | included in all copies or substantial portions of the Software. |
|               + GENERALS +                |                                                                 |
| - use snake case                          | THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, |
|                                           | EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES |
|                + PREFIX +                 | OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND        |
| - m: supports multiple qubits             | NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT     |
| - t: supports topological based           | HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,    |
|                                           | WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING    |
|                + SUFFIX +                 | FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR   |
| - _ex: extra/expanded version of function | OTHER DEALINGS IN THE SOFTWARE.                                 |
+-CREDITS-----------------------------------+-----------------------------------------------------------------+
| made by: axtr       > @axtrct             |
|          jiface     > @ssynical           |
|          plusgiant5 > @plusgiant5         |
|                                           |
|    used: greg hewgill's picomath          |                                                                 
+-------------------------------------------+-----------------------------------------------------------------+
