#!/usr/bin/perl
# Test try()

use warnings;
use strict;
use lib 'lib', '../lib';

use File::Temp   qw/tempfile/;
use Test::More tests => 23;

use Log::Report undef, syntax => 'SHORT';

use POSIX ':locale_h', 'setlocale';  # avoid user's environment

setlocale(LC_ALL, 'POSIX');

# start a new logger
my $text = '';
open my($fh), '>', \$text;

dispatcher close => 'default';
dispatcher FILE => 'out', to => $fh, accept => 'ALL';

cmp_ok(length $text, '==', 0, 'created normal file logger');

my $text_l1 = length $text;
info "test";
my $text_l2 = length $text;
cmp_ok($text_l2, '>', $text_l1);

my @l1 = dispatcher 'list';
cmp_ok(scalar(@l1), '==', 1);
is($l1[0]->name, 'out');
try { my @l2 = dispatcher 'list';
      cmp_ok(scalar(@l2), '==', 1);
      is($l2[0]->name, 'try', 'only try dispatcher');
      error __"this is an error"
    };
my $caught = $@;   # be careful with this... Test::More may spoil it.
my @l3 = dispatcher 'list';
cmp_ok(scalar(@l3), '==', 1);
is($l3[0]->name, 'out', 'original dispatcher restored');

isa_ok($caught, 'Log::Report::Dispatcher::Try');
ok($caught->failed);
ok($caught ? 1 : 0);
my @r1 = $caught->exceptions;
cmp_ok(scalar(@r1), '==', 1);
isa_ok($r1[0], 'Log::Report::Exception');
my @r2 = $caught->wasFatal;
cmp_ok(scalar(@r2), '==', 1);
isa_ok($r2[0], 'Log::Report::Exception');

try { info "nothing wrong";
      trace "trace more"
    }   # no comma!
    mode => 'DEBUG';

$caught = $@;
isa_ok($caught, 'Log::Report::Dispatcher::Try');
ok($caught->success);
ok($caught ? 0 : 1);
my @r3 = $caught->wasFatal;
cmp_ok(scalar(@r3), '==', 0);
my @r4 = $caught->exceptions;
cmp_ok(scalar(@r4), '==', 2);

$caught->reportAll;  # pass on errors
my $text_l3 = length $text;
cmp_ok($text_l3, '>', $text_l2, 'passed on loggings');
is(substr($text, $text_l2), <<__EXTRA);
info: nothing wrong
trace: trace more
__EXTRA

eval {
   try { try { failure "oops! no network" };
         $@->reportAll;
       };
   $@->reportAll;
};
is($@, "try-block stopped with FAILURE");
