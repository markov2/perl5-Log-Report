#oodist: *** DO NOT USE THIS VERSION FOR PRODUCTION ***
#oodist: This file contains OODoc-style documentation which will get stripped
#oodist: during its release in the distribution.  You can use this file for
#oodist: testing, however the code of this development version may be broken!

package Log::Report::Dispatcher::Try;
use base 'Log::Report::Dispatcher';

use warnings;
use strict;

use Log::Report 'log-report', syntax => 'SHORT';
use Log::Report::Exception ();
use Log::Report::Util      qw/%reason_code expand_reasons/;
use List::Util             qw/first/;

#--------------------
=chapter NAME
Log::Report::Dispatcher::Try - capture all reports as exceptions

=chapter SYNOPSIS
  try { ... };       # mind the ';' !!
  if($@) {           # signals something went wrong

  if(try {...}) {    # block ended normally

  my $x = try { read_temperature() };
  my @x = try { read_lines_from_file() };

  try { ... }        # no comma!!
     mode => 'DEBUG', accept => 'ERROR-';

  try sub { ... },   # with comma
     mode => 'DEBUG', accept => 'ALL';

  try \&myhandler, accept => 'ERROR-';
  try { ... } hide => 'TRACE';

  print ref $@;      # Log::Report::Dispatcher::Try

  $@->reportFatal;   # re-dispatch result of try block
  $@->reportAll;     # ... also warnings etc
  if($@) {...}       # if errors
  if($@->failed) {   # same       # }
  if($@->success) {  # no errors  # }

  try { # something causes an error report, which is caught
        failure 'no network';
      };
  $@->reportFatal(to => 'syslog');  # overrule destination

  print $@->exceptions; # no re-cast, just print

=chapter DESCRIPTION
The B<try> works like Perl's build-in C<eval()>, but implements
real exception handling which Perl core lacks.

The M<Log::Report::try()> function creates this C<::Try> dispatcher
object with name 'try'.  After the C<try()> is over, you can find
the object in C<$@>.  The C<$@> as C<::Try> object behaves exactly
as the C<$@> produced by C<eval>, but has many added features.

The C<try()> function catches fatal errors happening inside the BLOCK
(CODE reference which is just following the function name) into the
C<::Try> object C<$@>.  The errors are not automatically progressed to
active dispatchers.  However, non-fatal exceptions (like info or notice)
are also collected (unless not accepted, see M<new(accept)>, but also
immediately passed to the active dispatchers (unless the reason is hidden,
see M<new(hide)>)

After the C<try()> has run, you can introspect the collected exceptions.
Typically, you use M<wasFatal()> to get the exception which terminated
the run of the BLOCK.

=chapter OVERLOADED

=overload bool boolean
Returns true if the previous try block did produce a terminal
error.  This "try" object is assigned to C<$@>, and the usual
perl syntax is C<if($@) {...error-handler...}>.

=overload "" stringify
When C<$@> is used the traditional way, it is checked to have
a string content.  In this case, stringify into the fatal error
or nothing.
=cut

use overload
	bool     => 'failed',
	'""'     => 'showStatus',
	fallback => 1;

#--------------------
=chapter METHODS

=section Constructors

=c_method new $type, $name, %options
=option  exceptions \@objects
=default exceptions []
ARRAY of Log::Report::Exception objects.

=option  died $text
=default died undef
The exit string or object (C<$@>) of the eval'ed block, in its unprocessed state.

=option  hide $reasons|\@reasons|'ALL'|'NONE'
=default hide 'NONE'
[1.09] see M<hide()>

=option  on_die 'ERROR'|'PANIC'
=default on_die 'ERROR'
When code which runs in this block exits with a die(), it will get
translated into a Log::Report::Exception using
M<Log::Report::Die::die_decode()>.  How serious are we about these
errors?

=cut

sub init($)
{	my ($self, $args) = @_;
	defined $self->SUPER::init($args) or return;

	$self->{exceptions} = delete $args->{exceptions} || [];
	$self->{died}       = delete $args->{died};
	$self->hide($args->{hide} // 'NONE');
	$self->{on_die}     = $args->{on_die} // 'ERROR';
	$self;
}

#--------------------
=section Accessors

=method died [$text]
The exit $text or object (C<$@>) of the eval'ed block, in its unprocessed state.
They will always return true when they where deadly, and it always stringifies
into something useful.
=cut

sub died(;$)
{	my $self = shift;
	@_ ? ($self->{died} = shift) : $self->{died};
}

=method exceptions
Returns all collected Log::Report::Exception objects.  The last of
them may be a fatal one.  The other are non-fatal.
=cut

sub exceptions() { @{ $_[0]->{exceptions}} }

=method hides $reason
Check whether the try stops message which were produced for $reason.
=cut

sub hides($) { $_[0]->{LRDT_hides}{$_[1]} }

=method hide @reasons
[1.09] By default, the try will only catch messages which stop the
execution of the block (errors etc, internally a 'die').  Other messages
are passed to the parent dispatchers.

This option gives the opportunity to stop, for instance, trace messages.
Those messages are still collected inside the try object (unless excluded
by M<new(accept)>), so may get passed-on later via M<reportAll()> if
you like.

Be warned: Using this method will reset the whole 'hide' configuration:
it's a I<set> not an I<add>.

=example change the setting of the running block
  my $parent_try = dispatcher 'active-try';
  $parent_try->hide('ALL');
=cut

sub hide(@)
{	my $self = shift;
	my @reasons = expand_reasons(@_ > 1 ? \@_ : shift);
	$self->{LRDT_hides} = +{ map +($_ => 1), @reasons };
}

=method die2reason
Returns the value of M<new(on_die)>.
=cut

sub die2reason() { $_[0]->{on_die} }

#--------------------
=section Logging

=method log $opts, $reason, $message
Other dispatchers translate the message here, and make it leave the
program.  However, messages in a "try" block are only captured in
an intermediate layer: they may never be presented to an end-users.
And for sure, we do not know the language yet.

The $message is either a STRING or a Log::Report::Message.
=cut

sub log($$$$)
{	my ($self, $opts, $reason, $message, $domain) = @_;

	unless($opts->{stack})
	{	my $mode = $self->mode;
		$opts->{stack} = $self->collectStack
			if $reason eq 'PANIC'
			|| ($mode==2 && $reason_code{$reason} >= $reason_code{ALERT})
			|| ($mode==3 && $reason_code{$reason} >= $reason_code{ERROR});
	}

	$opts->{location} ||= '';

	push @{$self->{exceptions}},
		Log::Report::Exception->new(reason => $reason, report_opts => $opts, message => $message);

	$self;
}

=method reportAll %options
Re-cast the messages in all collect exceptions into the defined
dispatchers, which were disabled during the try block. The %options
will end-up as HASH of %options to M<Log::Report::report()>; see
M<Log::Report::Exception::throw()> which does the job.

=method reportFatal %options
Re-cast only the fatal message to the defined dispatchers.  If the
block was left without problems, then nothing will be done.  The %options
will end-up as HASH of %options to M<Log::Report::report()>; see
M<Log::Report::Exception::throw()> which does the job.
=cut

sub reportFatal(@) { my $s = shift; $_->throw(@_) for $s->wasFatal   }
sub reportAll(@)   { my $s = shift; $_->throw(@_) for $s->exceptions }

#--------------------
=section Status

=method failed
Returns true if the block was left with an fatal message.

=method success
Returns true if the block exited normally.
=cut

sub failed()  {   defined shift->{died} }
sub success() { ! defined shift->{died} }

=method wasFatal %options
Returns the Log::Report::Exception which caused the "try" block to
die, otherwise an empty LIST (undef).

=option  tag $tag|REGEX
=default tag undef
[1.44] Only return the exception if it was fatal, and in the same time in
the specified $tag (as string) or matches the REGEX.
See M<Log::Report::Message::taggedWith()>

=option  class $class|REGEX
=default class undef
Deprecated alternative for C<tag>.
=cut

sub wasFatal(@)
{	my ($self, %args) = @_;
	defined $self->{died} or return ();

	my $ex = first { $_->isFatal } @{$self->{exceptions}}
		or return ();

	my $tag = $args{tag} // $args{class};

	# There can only be one fatal exception.  Is it in the class?
	(! $tag || $ex->taggedWith($tag)) ? $ex : ();
}

=method showStatus
If this object is kept in C<$@>, and someone uses this as string, we
want to show the fatal error message.

The message is not very informative for the good cause: we do not want
people to simply print the C<$@>, but wish for a re-cast of the message
using M<reportAll()> or M<reportFatal()>.
=cut

sub showStatus()
{	my $self  = shift;
	my $fatal = $self->wasFatal or return '';
	__x"try-block stopped with {reason}: {text}", reason => $fatal->reason, text => $self->died;
}

1;
