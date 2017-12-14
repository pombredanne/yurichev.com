m4_include(`commons.m4')

_HEADER_HL1(`Cracking Minesweeper with PIN')

<p>(Previously: _HTML_LINK(`https://yurichev.com/blog/PIN_XOR/',`Using PIN DBI for XOR interception').)</p>

<p>In my "Reverse Engineering for Beginners" book I wrote about cracking Minesweeper for Windows XP: _HTML_LINK_AS_IS(`https://beginners.re/23-Jun-2017/RE4B-EN.pdf#page=822&zoom=auto,-273,414').</p>

<p>The Minesweeper in Windows Vista and 7 is different: probably it was (re)written to C++, and a cell information
is now stored not in global array, but rather in malloc'ed heap blocks.</p>

<p>This is a case when we can try PIN DBI tool.</p>

_HL2(`Intercepting all rand() calls')

<p>First, since Minesweeper places mines randomly, it has to call rand() or similar function.
Let's intercept all rand() calls: _HTML_LINK(`https://github.com/DennisYurichev/yurichev.com/blob/master/blog/minesweeper_PIN/minesweeper1.cpp',`minesweeper1.cpp').</p>

<p>Now we can run it:</p>

_PRE_BEGIN
c:\pin-3.2-81205-msvc-windows\pin.exe -t minesweeper1.dll -- C:\PATH\TO\MineSweeper.exe
_PRE_END

<p>During startup, PIN searches for all calls to rand() function and adds a hook right after each call.
The hook is the RandAfter() function we defined: it is logging about return value and also about return address.
Here is a log I got during run of standard 9*9 configuration (10 mines): _HTML_LINK(`https://github.com/DennisYurichev/yurichev.com/blob/master/blog/minesweeper_PIN/minesweeper1.out.10mines',`minesweeper1.out.10mines').
The rand() function was called many times from several places, but was called from 0x10002770d just 10 times.
I switched Minesweeper to 16*16 configuration (40 mines) and rand() was called from 0x10002770d 40 times.
So yes, this is our point.
When I load minesweeper.exe (from Windows 7) into IDA and PDB from Microsoft website is fetched,
the function which calls rand() at 0x10002770d called Board::placeMines().</p>

_HL2(`Replacing rand() calls with our function')

<p>Let's now try to replace rand() function with our version, let it always return zero: _HTML_LINK(`https://github.com/DennisYurichev/yurichev.com/blob/master/blog/minesweeper_PIN/minesweeper2.cpp',`minesweeper2.cpp').
During startup, PIN replaces all calls to rand() to calls to our function, which writes to log and returns zero.
OK, I run it, and clicked on leftmost/topmost cell:</p>

<p><img src="minesweeper1.png"></p>

<p>Yes, unlike Minesweeper from Windows XP, mines are places randomly <i>after</i> user's click on cell, so to guarantee
there is no mine at the cell user first clicked.
So Minesweeper placed cells on cells other than leftmost/topmost (where I clicked).</p>

<p>Now I clicked on rightmost/topmost cell:</p>

<p><img src="minesweeper2.png"></p>

<p>This can be some kind of practical joke? I don't know.</p>

<p>I clicked on 5th cell (right at the middle) at the 1st row:</p>

<p><img src="minesweeper3.png"></p>

<p>This is nice, because Minesweeper can do some correct placement even with such broken PRNG!</p>

_HL2(`Peeking into placement of mines')

<p>How can we get information about where mines are placed?
rand()'s result is seems to be useless: it returned zero all the time, but Minesweeper somehow managed to place
mines in different cells, though, lined up.</p>

<p>This Minesweeper also written in C++ tradition, so it has no global arrays.</p>

<p>Let us put ourselves in the position of programmer.
It has to be loop like:</p>

_PRE_BEGIN
for (int i; i&lt;mines_total; i++)
{
	// get coordinates using rand()
	// put a cell: in other words, modify a block allocated in heap
};
_PRE_END

<p>How can we get information about heap block which gets modified at the 2nd step?
What we need to do:
1) track all heap allocations by intercepting malloc()/realloc()/free().
2) track all memory writes (slow).
3) intercept calls to rand().</p>

<p>Now the algorithm:
1) mark all heap blocks gets modified between 1st and 2nd call to rand() from 0x10002770d;
2) whenever heap block gets freed, dump its contents.</p>

<p>Tracking all memory writes is slow, but after 2nd call to rand(), we don't need to track it (since we've got already a list of blocks of interest at this point), so we turn it off.</p>

<p>Now the code: _HTML_LINK(`https://github.com/DennisYurichev/yurichev.com/blob/master/blog/minesweeper_PIN/minesweeper3.cpp',`minesweeper3.cpp').</p>

<p>As it turns out, only 4 heap blocks gets modified between first two rand() calls, this is how they looks like:</p>

_PRE_BEGIN
free(0x20aa6360)
free(): we have this block in our records, size=0x28
0x20AA6360: 36 00 00 00 4E 00 00 00-2D 00 00 00 29 00 00 00 "6...N...-...)..."
0x20AA6370: 06 00 00 00 37 00 00 00-35 00 00 00 19 00 00 00 "....7...5......."
0x20AA6380: 46 00 00 00 0B 00 00 00-                        "F.......        "

...

free(0x20af9d10)
free(): we have this block in our records, size=0x18
0x20AF9D10: 0A 00 00 00 0A 00 00 00-0A 00 00 00 00 00 00 00 "................"
0x20AF9D20: 60 63 AA 20 00 00 00 00-                        "`c. ....        "

...

free(0x20b28b20)
free(): we have this block in our records, size=0x140
0x20B28B20: 02 00 00 00 03 00 00 00-04 00 00 00 05 00 00 00 "................"
0x20B28B30: 07 00 00 00 08 00 00 00-0C 00 00 00 0D 00 00 00 "................"
0x20B28B40: 0E 00 00 00 0F 00 00 00-10 00 00 00 11 00 00 00 "................"
0x20B28B50: 12 00 00 00 13 00 00 00-14 00 00 00 15 00 00 00 "................"
0x20B28B60: 16 00 00 00 17 00 00 00-18 00 00 00 1A 00 00 00 "................"
0x20B28B70: 1B 00 00 00 1C 00 00 00-1D 00 00 00 1E 00 00 00 "................"
0x20B28B80: 1F 00 00 00 20 00 00 00-21 00 00 00 22 00 00 00 ".... ...!..."..."
0x20B28B90: 23 00 00 00 24 00 00 00-25 00 00 00 26 00 00 00 "#...$...%...&..."
0x20B28BA0: 27 00 00 00 28 00 00 00-2A 00 00 00 2B 00 00 00 "'...(...*...+..."
0x20B28BB0: 2C 00 00 00 2E 00 00 00-2F 00 00 00 30 00 00 00 ",......./...0..."
0x20B28BC0: 31 00 00 00 32 00 00 00-33 00 00 00 34 00 00 00 "1...2...3...4..."
0x20B28BD0: 38 00 00 00 39 00 00 00-3A 00 00 00 3B 00 00 00 "8...9...:...;..."
0x20B28BE0: 3C 00 00 00 3D 00 00 00-3E 00 00 00 3F 00 00 00 "<...=...>...?..."
0x20B28BF0: 40 00 00 00 41 00 00 00-42 00 00 00 43 00 00 00 "@...A...B...C..."
0x20B28C00: 44 00 00 00 45 00 00 00-47 00 00 00 48 00 00 00 "D...E...G...H..."
0x20B28C10: 49 00 00 00 4A 00 00 00-4B 00 00 00 4C 00 00 00 "I...J...K...L..."
0x20B28C20: 4D 00 00 00 4F 00 00 00-50 00 00 00 50 00 00 00 "M...O...P...P..."
0x20B28C30: 50 00 00 00 50 00 00 00-50 00 00 00 50 00 00 00 "P...P...P...P..."
0x20B28C40: 50 00 00 00 50 00 00 00-50 00 00 00 50 00 00 00 "P...P...P...P..."
0x20B28C50: 50 00 00 00 00 00 00 00-00 00 00 00 00 00 00 00 "P..............."

...

free(0x20af9cf0)
free(): we have this block in our records, size=0x18
0x20AF9CF0: 43 00 00 00 50 00 00 00-10 00 00 00 20 00 74 00 "C...P....... .t."
0x20AF9D00: 20 8B B2 20 00 00 00 00-                        " .. ....        "
_PRE_END

<p>We can easily see that the biggest blocks (with size 0x28 and 0x140) are just arrays of values up to ~0x50.
Wait... 0x50 is 80 in decimal representation. And 9*9=81 (standard minesweeper configuration).</p>

<p>After quick investigation, I've found that each 32-bit element is indeed cell coordinate.
A cell is represented using a single number, it's a number inside of 2D-array.
Row and column of each mine is decoded like that: <i>row=n / WIDTH; col=n % HEIGHT;</i></p>

<p>So when I tried to decode these two biggest blocks, I've got these cell maps:</p>

_PRE_BEGIN
try_to_dump_cells(). unique elements=0xa
......*..
..*......
.......*.
.........
.....*...
*.......*
**.......
.......*.
......*..

...

try_to_dump_cells(). unique elements=0x44
*.****.**
...******
*******.*
*********
*****.***
.*******.
..*******
*******.*
******.**
_PRE_END

<p>It seems that the first block is just a list of mines placed, while the second block is a list of free cells, but, the second is somewhat out of sync with the first one,
and it's negative version of the first one coincides only partially.
Nevertheless, the first map is correct - we can peek into it in log file when Minesweeper is still loaded and almost all cells are hidden, and click safely on cells marked as dots here.</p>

<p>So it seems, when user first clicked somewhere, Minesweeper places 10 mines, than destroys the block with a list of it (perhaps, it copies all the data to another block before?),
so we can see it during free() call.</p>

<p>Another fact: the method Array&lt;NodeType>::Add(NodeType) modifies blocks we observed, and is called from various places, including Board::placeMines().
But what is cool: I never got into its details, everything has been resolved using just PIN.</p>

<p>The files: _HTML_LINK_AS_IS(`https://github.com/DennisYurichev/yurichev.com/tree/master/blog/minesweeper_PIN').</p>

_HL2(`Exercise')

<p>Try to understand how rand()'s result being converted into coordinate(s).
As a practical joke, make rand() to output such results, so mines will be placed in shape of some symbol or figure.</p>

<p><h5>(The post was first published at 24-Jun-2017.)</h5></p>

_BLOG_FOOTER()

