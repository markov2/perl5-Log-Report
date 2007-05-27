#!/usr/bin/perl
use warnings;
use strict;
use lib 'lib', '../lib';

use Test::More tests => 13;

use_ok('Log::Report');
use_ok('Log::Report::Dispatcher');
use_ok('Log::Report::Dispatcher::File');
use_ok('Log::Report::Dispatcher::Try');
use_ok('Log::Report::Exception');
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
