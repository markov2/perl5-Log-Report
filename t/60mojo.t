#!/usr/bin/env perl
# Test MojoX::Log::Report

use warnings;
use strict;
use lib 'lib', '../lib';

use Test::More;
use Log::Report undef;

use Data::Dumper;

BEGIN
{   eval "require Mojo::Base";
    plan skip_all => 'Mojo is not installed'
        if $@;

    plan tests => 7;
}

use_ok('MojoX::Log::Report');

my $log = MojoX::Log::Report->new;
isa_ok($log, 'MojoX::Log::Report');
isa_ok($log, 'Mojo::Log');

my $tmp;
try { $log->error("going to die"); $tmp = 42 } mode => 3;
my $err = $@;
#warn Dumper $err;

cmp_ok($tmp, '==', 42, 'errors not cast directly');
ok($@->success, 'block continued succesfully');

my @exc = $err->exceptions;
cmp_ok(scalar @exc, '==', 1, "caught 1");
is("$exc[0]", "error: going to die\n");
