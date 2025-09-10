#oodist: *** DO NOT USE THIS VERSION FOR PRODUCTION ***
#oodist: This file contains OODoc-style documentation which will get stripped
#oodist: during its release in the distribution.  You can use this file for
#oodist: testing, however the code of this development version may be broken!

package Dancer::Logger::LogReport;
use base 'Dancer::Logger::Abstract', 'Exporter';

use strict;
use warnings;

use Scalar::Util            qw/blessed/;
use Log::Report             'log-report', import => 'report';
use Log::Report::Dispatcher ();

our $AUTHORITY = 'cpan:MARKOV';

our @EXPORT    = qw/
	trace
	assert
	notice
	alert
	panic
/;

my %level_dancer2lr =
( core  => 'TRACE',
	debug => 'TRACE'
);

#--------------------
=chapter NAME

Dancer::Logger::LogReport - reroute Dancer logs into Log::Report

=chapter SYNOPSIS

  # When your main program is not a Dancer object
  use My::Dancer::App;
  use Log::Report;
  ... start dispatcher ...
  error "something is wrong";   # Log::Report::error()

  # When your main program is a Dancer object
  use Dancer;
  use Dancer::Logger::LogReport;
  use Log::Report import => 'dispatcher';
  ... start dispatcher ...
  error "something is wrong";   # Dancer::error()

  # In any case, your main program needs to start log dispatcers
  # Both Dancer and other Log::Report based modules will send
  # their messages here:
  dispatcher FILE => 'default', ...;

  # In your config
  logger: log_report
  logger_format: %i%m   # keep it simple
  log: debug            # filtered by dispatchers

=chapter DESCRIPTION

The Log::Report exception/translation framework defines a large
number of logging back-ends.  The same log messages can be sent to
multiple destinations at the same time via flexible dispatchers.
When you use this logger in your Dancer application, it will nicely
integrate with non-Dancer modules which need logging.

Many log back-ends, like syslog, have more levels of system messages.
Modules who explicitly load this module can use the missing C<assert>,
C<notice>, C<panic>, and C<alert> log levels.  The C<trace> name is
provided as well: when you are debugging, you add a 'trace' to your
program... its just a better name than 'debug'.

You probably want to set a very simple C<logger_format>, because the
dispatchers do already add some of the fields that the default
C<simple> format adds.  For instance, to get the filename/line-number
in messages depends on the dispatcher 'mode' (f.i. 'DEBUG').

You also want to set the log level to C<debug>, because level filtering
is controlled per dispatcher (as well)

=cut

# Add some extra 'levels'
sub trace   { goto &Dancer::Logger::debug  }
sub assert  { goto &Dancer::Logger::assert }
sub notice  { goto &Dancer::Logger::notice }
sub panic   { goto &Dancer::Logger::panic  }
sub alert   { goto &Dancer::Logger::alert  }

sub Dancer::Logger::assert { my $l = logger(); $l && $l->_log(assert => _serialize(@_)) }
sub Dancer::Logger::notice { my $l = logger(); $l && $l->_log(notice => _serialize(@_)) }
sub Dancer::Logger::alert  { my $l = logger(); $l && $l->_log(alert  => _serialize(@_)) }
sub Dancer::Logger::panic  { my $l = logger(); $l && $l->_log(panic  => _serialize(@_)) }

sub _log {
	my ($self, $level, $params) = @_;

	# all dancer levels are the same as L::R levels, except:
	my $msg;
	if(blessed $params && $params->isa('Log::Report::Message'))
	{	$msg = $params;
	}
	else
	{	$msg = $self->format_message($level => $params);
		$msg =~ s/\n+$//;
	}

	# The levels are nearly the same.
	my $reason = $level_dancer2lr{$level} // uc $level;

	# Gladly, report() does not get confused between Dancer's use of
	# Try::Tiny and Log::Report's try() which starts a new dispatcher.
	report +{ is_fatal => 0 }, $reason => $msg;

	undef;
}

1;
