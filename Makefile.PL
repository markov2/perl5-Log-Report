use ExtUtils::MakeMaker;

use 5.008;

my $version = '0.992';

my %prereq  =
  ( Test::More   =>  0.86
  , Sys::Syslog  => '0.27'
  , Encode       => '2.00'
  , Scalar::Util => 0
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
SKIP_LINKS	= XML::LibXML

# for OODoc's oodist, POD
FIRST_YEAR      = 2007
EMAIL           = perl@overmeer.net
WEBSITE         = http://perl.overmeer.net/log-report/
EXTENDS		= 

# for OODoc's oodist, HTML
HTML_OUTPUT     = ../public_html/log-report/html
HTML_DOCROOT    = /log-report/html
HTML_PACKAGE    = ../public_html/log-report/htmlpkg

# for Log::Report
xgettext: $(TO_INST_PM)
	PERL5LIB=lib bin/xgettext-perl --mode=DEBUG \
	    -p lib/Log/Report/messages lib bin
__POSTAMBLE
