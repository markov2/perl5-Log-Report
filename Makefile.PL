use ExtUtils::MakeMaker;

use 5.008;

my $version = 0.13;

my %prereq  =
  ( Test::More => 0.47
  , Test::Pod  => 1.00
  );

$prereq{ 'Win32::TieRegistry' } = 0.24
    if $^O eq 'MSWin32';

WriteMakefile
  ( NAME      => 'Log::Report'
  , VERSION   => $version
  , PREREQ_PM => \%prereq
  , EXE_FILES => [ 'bin/xgettext-perl' ]

  , AUTHOR    => 'Mark Overmeer'
  , ABSTRACT  => 'report a problem, pluggable handlers and language support'
  , LICENSE   => 'perl'
  );

sub MY::postamble { <<'__POSTAMBLE' }

# for OODoc's oodist, DIST
RAWDIR          = ../public_html/log-report/raw
DISTDIR         = ../public_html/log-report/source
LICENSE         = artistic

# for OODoc's oodist, POD
FIRST_YEAR      = 2007
EMAIL           = perl@overmeer.net
WEBSITE         = http://perl.overmeer.net/log-report/
EXTENDS		= ../LogReportView

# for OODoc's oodist, HTML
HTML_OUTPUT     = ../public_html/log-report/html
HTML_DOCROOT    = /log-report/html
HTML_PACKAGE    = ../public_html/log-report/htmlpkg

# for Log::Report
xgettext: $(TO_INST_PM)
	PERL5LIB=lib bin/xgettext-perl --mode=VERBOSE \
	    -p lib/Log/Report/messages
__POSTAMBLE
