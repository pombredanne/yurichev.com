m4_include(`commons.m4')

_HEADER_HL1(`Can rand() generate 10 consecutive zeroes?')

<p>I've always been wondering, if it's possible or not.
As of simplest linear congruential generator from MSVC's rand(), I could get a state at which rand() will output 8 zeroes modulo 10:</p>

_PRE_BEGIN
m4_include(`blog/LCG_Z3//LCG10.py')
_PRE_END

_PRE_BEGIN
sat
[state3 = 1181667981,
 state4 = 342792988,
 state5 = 4116856175,
 state7 = 1741999969,
 state8 = 3185636512,
 state2 = 1478548498,
 state6 = 4036911734,
 state1 = 286227003,
 state9 = 1700675811]
_PRE_END

<p>This is a case if, in some video game, you'll find a code:</p>

_PRE_BEGIN
for (int i=0; i<8; i++)
    printf ("%d\n", rand() % 10);
_PRE_END

<p>... and at some point, this piece of code can generate 8 zeroes in row, if the state will be 286227003 (decimal).</p>

Just checked this piece of code in MSVC 2015:

_PRE_BEGIN
#include <stdio.h>

int main()
{
	srand(286227003);

	for (int i=0; i<8; i++)
		printf ("%d\n", rand() % 10);
};
_PRE_END

<p>Yes, it generates 8 zeroes!</p>

<p>What about other modulos?</p>

<p>I can get 4 consecutive zeroes modulo 100:</p>

_PRE_BEGIN
m4_include(`blog/LCG_Z3//LCG100.py')
_PRE_END

_PRE_BEGIN
sat
[state3 = 635704497,
 state4 = 1644979376,
 state2 = 1055176198,
 state1 = 3865742399,
 state5 = 1389375667]
_PRE_END

<p>... and 3 consecutive zeroes modulo 1000:</p>

_PRE_BEGIN
m4_include(`blog/LCG_Z3//LCG100.py')
_PRE_END

_PRE_BEGIN
sat
[state3 = 1179663182,
 state2 = 720934183,
 state1 = 4090229556,
 state4 = 786474201]
_PRE_END

<p>What if we could use rand()'s output without division? Which is in 0..0x7fff range (i.e., 15 bits)?
As it can be checked quickly, 2 zeroes at output is possible:</p>

_PRE_BEGIN
m4_include(`blog/LCG_Z3//LCG.py')
_PRE_END

_PRE_BEGIN
sat
[state2 = 20057, state1 = 3385131726, state3 = 22456]
_PRE_END

<p>The files: _HTML_LINK_AS_IS(`https://github.com/dennis714/yurichev.com/tree/master/blog/LCG_Z3').</p>

<p>See also: _HTML_LINK(`https://yurichev.com/blog//compress/',`Text strings right in the middle of compressed data').
Also, my _HTML_LINK(`https://yurichev.com/writings/SAT_SMT_draft-EN.pdf',`SAT/SMT notes') has another LCG-related example.</p>

<p>Further work: check glibc's rand(), Mersenne Twister, etc.</p>

_FOOTER()

