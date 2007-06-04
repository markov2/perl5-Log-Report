use ExtUtils::MakeMaker;

use 5.8.2;

WriteMakefile
  ( NAME      => 'Log::Report'
  , VERSION   => '0.04'
  , PREREQ_PM => { Test::More => 0.47 }

  , EXE_FILES => [ 'bin/xgettext-perl' ]

  , AUTHOR    => 'Mark Overmeer'
  , ABSTRACT  => 'report a problem, pluggable handlers and language support'
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

# for OODoc's oodist, HTML
HTML_OUTPUT     = ../public_html/log-report/html
HTML_DOCROOT    = /log-report/html
HTML_PACKAGE    = ../public_html/log-report/htmlpkg

# for Log::Report
xgettext: $(TO_INST_PM)
	PERL5LIB=lib bin/xgettext-perl --mode=DEBUG \
	    -p lib/Log/Report/messages
__POSTAMBLE
