#!/usr/bin/perl
# Try __

use warnings;
use strict;
use lib 'lib', '../lib';

use Test::More tests => 63;

use Log::Report;   # no domains, no translator
use Scalar::Util qw/reftype/;

### examples from Log::Report::Message and more

my $a = __"Hello";
ok(defined $a);
is(ref $a, 'Log::Report::Message');
is(reftype $a, 'HASH');
is(__"Hello World",        'Hello World');
is(__"Hello World {a}",    'Hello World {a}');
is(__('Hello World {a}'),  'Hello World {a}');

my $c = __x"Hello";
ok(defined $c);
is(ref $c, 'Log::Report::Message');
is(reftype $c, 'HASH');
is(__x("Hello World", a => 42),      'Hello World');
is(__x("Hello World {a}", a => 42),  'Hello World 42');
is((__x"Hello World {a}", a => 42),  'Hello World 42');
is((__x "Hello World {a}", a => 42), 'Hello World 42');
is((__x "{a}{a}{a}", a => 42),       '424242');

my $d = __n"Hello","World",3;
ok(defined $d);
is(ref $d, 'Log::Report::Message');
is(reftype $d, 'HASH');
is(__n("Hello", "World", 1),      'Hello');
is(__n("Hello", "World", 0),      'World');
is(__n("Hello", "World", 2),      'World');

my $e = __nx"Hello","World",3,a=>42;
ok(defined $e);
is(ref $e, 'Log::Report::Message');
is(reftype $e, 'HASH');
is(__nx("Hel{a}lo", "Wor{a}ld", 1,a=>42),      'Hel42lo');
is(__nx("Hel{a}lo", "Wor{a}ld", 0,a=>42),      'Wor42ld');
is(__nx("Hel{a}lo", "Wor{a}ld", 2,a=>42),      'Wor42ld');
is(__xn("Hel{a}lo", "Wor{a}ld", 2,a=>42),      'Wor42ld');

my $e1 = 1;
is((__nx "one", "more", $e1++), "one");
is((__nx "one", "more", $e1), "more");
my @files = 'monkey';
my $nr_files = @files;
is((__nx "one file", "{_count} files", $nr_files), 'one file');
is((__nx "one file", "{_count} files", @files), 'one file');
push @files, 'donkey';
$nr_files = @files;
is((__nx "one file", "{_count} files", $nr_files), '2 files');
is((__nx "one file", "{_count} files", @files), '2 files');

my $f = N__"Hi";
ok(defined $f);
is(ref $f, '');
is(N__"Hi",   "Hi");
is((N__"Hi"), "Hi");
is(N__("Hi"), "Hi");

my @g = N__n "Hi", "bye";
cmp_ok(scalar @g, '==', 2);
is($g[0], 'Hi');
is($g[1], 'bye');

#
# Use _count directly
#

is(__nx("single {_count}", "multi {_count}", 0), 'multi 0');
is(__nx("single {_count}", "multi {_count}", 1), 'single 1');
is(__nx("single {_count}", "multi {_count}", 2), 'multi 2');

#
# Expand arrays
#
{
  local $" = ', ';
  my @one = 'rabbit';
  is((__x "files: {f}", f => \@files), "files: monkey, donkey");
  is((__xn "one file: {f}", "{_count} files: {f}", @files, f => \@files),
      "2 files: monkey, donkey");
  is((__x  "files: {f}", f => \@one), "files: rabbit");
  is((__xn "one file: {f}", "{_count} files: {f}", @one, f => \@one),
      "one file: rabbit");
} 

#
# clone
#

my $s2 = __x "found {nr} files", nr => 5;
my $t2 = $s2->(nr => 3);
isa_ok($t2, 'Log::Report::Message');
is($s2, 'found 5 files');
is($t2, 'found 3 files');

# clone by overload
my $s = __x "A={a};B={b}", a=>11, b=>12;
isa_ok($s, 'Log::Report::Message');
ok(reftype $s, 'HASH');
is($s->toString, "A=11;B=12");

my $t = $s->(b=>13);
isa_ok($t, 'Log::Report::Message');
ok(reftype $t, 'HASH');
isnt("$s", "$t");
is($t->toString, "A=11;B=13");
is($s->toString, "A=11;B=12");  # unchanged

#
# format
#

use constant PI => 4 * atan2(1, 1);
my $approx = 'approx pi: 3.141593';
is((sprintf "approx pi: %.6f", PI), $approx);
is((__x "approx pi: {approx}", approx => sprintf("%.6f", PI)), $approx);
is((__x "approx pi: {pi%.6f}", pi => PI), $approx);

is((__x "{perms} {links%2d} {user%-8s} {size%8d} {fn}"
         , perms => '-rw-r--r--', links => 1, user => 'superman'
         , size => '1234567', fn => '/etc/profile')
  , '-rw-r--r--  1 superman  1234567 /etc/profile');

