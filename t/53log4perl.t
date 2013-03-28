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

    plan tests => 5;
}

my ($out, $outfn) = tempfile;
my $name = 'logger';

# adapted from the docs
my $conf = <<__CONFIG;
log4perl.category.$name            = INFO, Logfile
log4perl.appender.Logfile          = Log::Log4perl::Appender::File
log4perl.appender.Logfile.filename = $outfn
log4perl.appender.Logfile.layout   = Log::Log4perl::Layout::PatternLayout
log4perl.appender.Logfile.layout.ConversionPattern = %d %F{2} %L> %m
__CONFIG

dispatcher 'Log::Log4perl' => $name, config => \$conf
   , to_level => ['ALERT-' => 3];

dispatcher close => 'default';

cmp_ok(-s $outfn, '==', 0);

my $date_qr = qr!\d{4}/\d{2}/\d{2} \d{2}:\d{2}:\d{2}!;
my ($line_number, $log_line, $expected_msg);
    
notice "this is a test"; $line_number = __LINE__;

my $s1 = -s $outfn;
cmp_ok($s1, '>', 0);
$log_line = <$out>;
$expected_msg = " $0 $line_number> notice: this is a test";
like($log_line, qr/^$date_qr\Q$expected_msg\E$/);

warning "some more"; $line_number = __LINE__;
my $s2 = -s $outfn;
cmp_ok($s2, '>', $s1);
$log_line = do { <$out> };
$expected_msg = " $0 $line_number> warning: some more";
like($log_line, qr/^$date_qr\Q$expected_msg\E$/);

unlink $outfn;

