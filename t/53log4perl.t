#!/usr/bin/env perl
# Test Log::Log4perl (only very simple tests)

use warnings;
use strict;

use File::Temp   qw/tempfile/;
use Test::More;

use Log::Report undef, syntax => 'SHORT';

BEGIN
{   eval "require Log::Log4perl";
    plan skip_all => 'Log::Log4perl not installed'
        if $@;

    my $sv = Log::Log4perl->VERSION;
    eval { Log::Log4perl->VERSION(1.00) };
    plan skip_all => "Log::Log4perl too old (is $sv, requires 1.00)"
        if $@;

    plan tests => 3;
}

my ($out, $outfn) = tempfile;
my $name = 'logger';

# adapted from the docs
my $conf = <<__CONFIG;
log4perl.category.$name            = INFO, Logfile
log4perl.appender.Logfile          = Log::Log4perl::Appender::File
log4perl.appender.Logfile.filename = $outfn
log4perl.appender.Logfile.layout   = Log::Log4perl::Layout::PatternLayout
log4perl.appender.Logfile.layout.ConversionPattern = %d %F{1} %L> %m
__CONFIG

dispatcher 'Log::Log4perl' => $name, config => \$conf
   , to_level => ['ALERT-' => 3];

dispatcher close => 'default';

cmp_ok(-s $outfn, '==', 0);
notice "this is a test";
my $s1 = -s $outfn;
cmp_ok($s1, '>', 0);

warning "some more";
my $s2 = -s $outfn;
cmp_ok($s2, '>', $s1);

unlink $outfn;
