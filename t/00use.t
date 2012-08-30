#!/usr/bin/env perl
use warnings;
use strict;

use Test::More tests => 18;

# The versions of the following packages are reported to help understanding
# the environment in which the tests are run.  This is certainly not a
# full list of all installed modules.
my @show_versions =
 qw/PPI
    POSIX
    Test::Pod
    Log::Log4perl
    Sys::Syslog
    Log::Dispatch
   /;

warn "Perl $]\n";
foreach my $package (sort @show_versions)
{   eval "require $package";

    my $report
      = !$@                    ? "version ". ($package->VERSION || 'unknown')
      : $@ =~ m/^Can't locate/ ? "not installed"
      : "reports error";

    warn "$package $report\n";
}

use_ok('Log::Report');
use_ok('Log::Report::Die');
use_ok('Log::Report::Dispatcher');
use_ok('Log::Report::Dispatcher::File');
use_ok('Log::Report::Dispatcher::Try');
use_ok('Log::Report::Dispatcher::Perl');
use_ok('Log::Report::Dispatcher::Callback');
use_ok('Log::Report::Exception');
use_ok('Log::Report::Extract');
use_ok('Log::Report::Extract::Template');
use_ok('Log::Report::Lexicon::Index');
use_ok('Log::Report::Lexicon::PO');
use_ok('Log::Report::Lexicon::POT');
use_ok('Log::Report::Lexicon::POTcompact');
use_ok('Log::Report::Message');
use_ok('Log::Report::Translator');
use_ok('Log::Report::Translator::POT');
use_ok('Log::Report::Util');

# Log::Report::Extract::PerlPPI         requires optional PPI
# Log::Report::Dispatcher::Syslog       requires optional Sys::Syslog
# Log::Report::Dispatcher::LogDispatch  requires optional Log::Dispatch
# Log::Report::Dispatcher::Log4perl     requires optional Log::Log4perl
# Log::Report::Translator::Gettext      requires optional Locale::gettext
