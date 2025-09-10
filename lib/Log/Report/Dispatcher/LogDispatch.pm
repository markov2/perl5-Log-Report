#oodist: *** DO NOT USE THIS VERSION FOR PRODUCTION ***
#oodist: This file contains OODoc-style documentation which will get stripped
#oodist: during its release in the distribution.  You can use this file for
#oodist: testing, however the code of this development version may be broken!
#oorestyle: old style disclaimer to be removed.

# This code is part of distribution Log-Report. Meta-POD processed with
# OODoc into POD and HTML manual-pages.  See README.md
# Copyright Mark Overmeer.  Licensed under the same terms as Perl itself.

package Log::Report::Dispatcher::LogDispatch;
use base 'Log::Report::Dispatcher';

use warnings;
use strict;

use Log::Report 'log-report', syntax => 'SHORT';
use Log::Report::Util  qw/@reasons expand_reasons/;

use Log::Dispatch 2.00;

my %default_reasonToLevel = (
	TRACE   => 'debug',
	ASSERT  => 'debug',
	INFO    => 'info',
	NOTICE  => 'notice',
	WARNING => 'warning',
	MISTAKE => 'warning',
	ERROR   => 'error',
	FAULT   => 'error',
	ALERT   => 'alert',
	FAILURE => 'emergency',
	PANIC   => 'critical',
);

@reasons != keys %default_reasonToLevel
	and panic __"Not all reasons have a default translation";

#--------------------
=chapter NAME
Log::Report::Dispatcher::LogDispatch - send messages to Log::Dispatch back-end

=chapter SYNOPSIS
  use Log::Dispatch::File;
  dispatcher Log::Dispatch::File => 'logger', accept => 'NOTICE-',
    filename => 'logfile', to_level => [ 'ALERT-' => 'err' ];

  # disable default dispatcher
  dispatcher close => 'logger';

=chapter DESCRIPTION
This dispatchers produces output to and C<Log::Dispatch> back-end.
(which will NOT be automatically installed for you).

The REASON for a message often uses names which are quite similar to the
log-levels used by Log::Dispatch.  However: they have a different
approach.  The REASON of Log::Report limits the responsibility of the
programmer to indicate the cause of the message: whether it was able to
handle a certain situation.  The Log::Dispatch levels are there for the
user's of the program.  However: the programmer does not known anything
about the application (in the general case).  This is cause of much of
the trickery in Perl programs.

The default translation table is list below.  You can change the mapping
using M<new(to_level)>.  See example in SYNOPSIS.

=chapter METHODS

=section Constructors

=c_method new $type, $name, %options
The Log::Dispatch infrastructure has quite a large number of output
TYPEs, each extending the Log::Dispatch::Output base-class.  You
do not create these objects yourself: Log::Report is doing it for you.

The Log::Dispatch back-ends are very careful with validating their
parameters, so you will need to restrict the options to what is supported
for the specific back-end.  See their respective manual-pages.  The errors
produced by the back-ends quite horrible and untranslated, sorry.

=option  to_level ARRAY-of-PAIRS
=default to_level []
See M<reasonToLevel()>.

=option  min_level $level
=default min_level C<debug>
Restrict the messages which are passed through based on the $level,
so after the reason got translated into a Log::Dispatch compatible
LEVEL.  The default will use Log::Report restrictions only.

=option  max_level $level
=default max_level undef
Like P<min_level>.

=option  callbacks CODE|ARRAY-of-CODE
=default callbacks []
See Log::Dispatch::Output.

=error Log::Dispatch level '$level' not understood
=cut

sub init($)
{	my ($self, $args) = @_;
	$self->SUPER::init($args);

	$args->{name}        = $self->name;
	$args->{min_level} ||= 'debug';

	$self->{level}  = { %default_reasonToLevel };
	if(my $to_level = delete $args->{to_level})
	{	my @to = @$to_level;
		while(@to)
		{	my ($reasons, $level) = splice @to, 0, 2;
			my @reasons = expand_reasons $reasons;

			Log::Dispatch->level_is_valid($level)
				or error __x"Log::Dispatch level '{level}' not understood", level => $level;

			$self->{level}{$_} = $level for @reasons;
		}
	}

	$self->{backend} = $self->type->new(%$args);
	$self;
}

sub close()
{	my $self = shift;
	$self->SUPER::close or return;
	delete $self->{backend};
	$self;
}

#--------------------
=section Accessors

=method backend
Returns the Log::Dispatch::Output object which is used for logging.
=cut

sub backend() { $_[0]->{backend} }

#--------------------
=section Logging
=cut

sub log($$$$$)
{	my $self  = shift;
	my $text  = $self->translate(@_) or return;
	my $level = $self->reasonToLevel($_[1]);

	$self->backend->log(level => $level, message => $text);
	$self;
}

=method reasonToLevel $reason
Returns a level which is understood by Log::Dispatch, based on
a translation table.  This can be changed with M<new(to_level)>.
=cut

sub reasonToLevel($) { $_[0]->{level}{$_[1]} }

1;
